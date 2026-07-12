import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MiniProfileModal extends StatefulWidget {
  const MiniProfileModal({super.key});

  @override
  State<MiniProfileModal> createState() => _MiniProfileModalState();
}

class _MiniProfileModalState extends State<MiniProfileModal> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: Get.height * .6,
      child: Dialog(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: .end,
                children: [
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: Icon(Icons.close),
                  ),
                ],
              ),
              Column(
                spacing: 4,
                crossAxisAlignment: .center,
                children: [
                  CircleAvatar(radius: 48),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 4,
                    children: [
                      Text(
                        "Niek Geerligs",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Image.asset("assets/badge-check.png", color: Colors.blue),
                    ],
                  ),
                  Chip(label: Text("Author")),
                ],
              ),
              Row(
                spacing: 4,
                children: [
                  Icon(Icons.import_contacts_outlined),
                  Text(
                    "Published Books",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              for (int i = 0; i < 3; i++)
                Card(
                  child: SizedBox(
                    width: double.maxFinite,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text("schatz der welten $i"),
                    ),
                  ),
                ),
              Container(
                width: double.maxFinite,
                height: 2,
                color: Get.theme.dividerColor,
              ),
              Text(
                "2 Shared Room",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              for (int i = 0; i < 2; i++) Text("fantasy and adventure club"),
            ],
          ),
        ),
      ),
    );
  }
}
