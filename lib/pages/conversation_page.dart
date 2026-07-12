import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:neuebranden_chat/pages/mini_profile_modal.dart';

class ConversationPage extends StatefulWidget {
  const ConversationPage({super.key, required String roomId});

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: Row(
          spacing: 4,
          mainAxisSize: .min,
          children: [
            CircleAvatar(),
            Column(
              crossAxisAlignment: .start,
              children: [
                Text(
                  "Title",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  "4 memebers",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemBuilder: (context, index) {
                    return Column(
                      crossAxisAlignment: .start,
                      children: [
                        //joined message
                        Align(
                          alignment: Alignment.center,
                          child: Chip(label: Text("Sophie joined the room")),
                        ),
                        //time message
                        Align(
                          alignment: Alignment.center,
                          child: Text(
                            DateFormat('hh:mm a').format(DateTime.now()),
                          ),
                        ),
                        //other person
                        Column(
                          children: [
                            Row(
                              children: [
                                InkWell(
                                  onTap: () {
                                    Get.to(() => MiniProfileModal());
                                  },
                                  child: CircleAvatar(),
                                ),
                                Text("Sophia Zimmerman"),
                              ],
                            ),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Column(
                                  children: [
                                    Text(
                                      "this is a message form another person",
                                    ),
                                    Row(
                                      mainAxisAlignment: .end,
                                      children: [
                                        Text(
                                          DateFormat(
                                            'HH:mm',
                                          ).format(DateTime.now()),
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: .end,
                          children: [
                            Card(
                              color: Get.theme.primaryColor,
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Column(
                                  children: [
                                    Text(
                                      "this is a message from me that i am currently testing for overflow yeah thats fun",
                                      style: TextStyle(
                                        color: Get.theme.colorScheme.onPrimary,
                                      ),
                                    ),
                                    Row(
                                      mainAxisAlignment: .end,
                                      children: [
                                        Text(
                                          DateFormat(
                                            'HH:mm',
                                          ).format(DateTime.now()),
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
              SizedBox(
                height: 120,
                child: Card(
                  child: Form(
                    child: Row(
                      spacing: 4,
                      children: [
                        IconButton(
                          onPressed: () {},
                          icon: Transform.rotate(
                            angle: .3,
                            child: Icon(Icons.attach_file),
                          ),
                        ),
                        Expanded(
                          child: TextFormField(
                            decoration: InputDecoration(
                              hintText: "Type a message...",
                              suffixIcon: Icon(Icons.mood),
                            ),
                          ),
                        ),
                        Transform.rotate(
                          angle: -.3,
                          child: IconButton(
                            onPressed: () {},
                            icon: Icon(Icons.send),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
