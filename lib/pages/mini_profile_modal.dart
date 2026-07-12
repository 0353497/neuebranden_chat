import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:neuebranden_chat/services/chat_api_service.dart';

class MiniProfileModal extends StatefulWidget {
  const MiniProfileModal({super.key, required this.user});
  final ChatUser user;
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
                spacing: 8,
                crossAxisAlignment: .center,
                children: [
                  CircleAvatar(
                    radius: 48,
                    foregroundImage: NetworkImage(widget.user.avatarUrl),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 4,
                    children: [
                      Text(
                        widget.user.name,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.user.isAuthor)
                        Image.asset(
                          "assets/badge-check.png",
                          color: Colors.blue,
                        ),
                    ],
                  ),
                  if (widget.user.isAuthor) Chip(label: Text("Author")),
                ],
              ),
              if (widget.user.isAuthor)
                Column(
                  crossAxisAlignment: .start,
                  children: [
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
                  ],
                ),
              for (int i = 0; i < widget.user.publishedBooks.length; i++)
                if (widget.user.isAuthor)
                  Card(
                    child: SizedBox(
                      width: double.maxFinite,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(widget.user.publishedBooks[i].toString()),
                      ),
                    ),
                  ),
              const SizedBox(height: 8),
              Container(
                width: double.maxFinite,
                height: 2,
                color: Get.theme.dividerColor,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    Text(
                      "${widget.user.sharedRooms.length} Shared Room(s)",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    for (int i = 0; i < widget.user.sharedRooms.length; i++)
                      Text(widget.user.sharedRooms[i]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
