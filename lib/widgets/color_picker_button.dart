import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ColorPickerButton extends StatelessWidget {
  const ColorPickerButton({
    super.key,
    required this.title,
    required this.color,
    required this.onChanged,
  });

  final String title;
  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color),
        title: Text(title),
        subtitle: Text(
          '#${color.red.toRadixString(16).padLeft(2, '0')}'
          '${color.green.toRadixString(16).padLeft(2, '0')}'
          '${color.blue.toRadixString(16).padLeft(2, '0')}'
              .toUpperCase(),
        ),
        trailing: const Icon(Icons.color_lens),
        onTap: () async {
          var selected = color;
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(title),
              content: SingleChildScrollView(
                child: ColorPicker(
                  pickerColor: selected,
                  onColorChanged: (value) => selected = value,
                  enableAlpha: false,
                  displayThumbColor: true,
                  portraitOnly: true,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    onChanged(selected);
                    Navigator.pop(context);
                  },
                  child: const Text('Select'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
