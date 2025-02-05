import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'facility_detail_screen.dart'; // 施設詳細画面をインポート

class ReservationTab extends StatelessWidget {
  const ReservationTab({Key? key}) : super(key: key);

  Future<String?> _getUserApartmentId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    return userDoc['apartment']; // ユーザーに関連付けられたマンションID
  }

  Future<List<Map<String, dynamic>>> _getFacilities(String apartmentId) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('facilities')
        .where('apartment_id', isEqualTo: apartmentId)
        .get();

    return querySnapshot.docs
        .map((doc) => {
              'id': doc.id,
              ...doc.data() as Map<String, dynamic>,
            })
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('施設予約'),
      ),
      body: FutureBuilder<String?>(
        future: _getUserApartmentId(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || snapshot.data == null) {
            return const Center(child: Text('マンション情報を取得できませんでした。'));
          }

          final apartmentId = snapshot.data!;

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _getFacilities(apartmentId),
            builder: (context, facilitySnapshot) {
              if (facilitySnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (facilitySnapshot.hasError ||
                  facilitySnapshot.data == null ||
                  facilitySnapshot.data!.isEmpty) {
                return const Center(child: Text('施設情報が見つかりませんでした。'));
              }

              final facilities = facilitySnapshot.data!;

              return ListView.builder(
                itemCount: facilities.length,
                itemBuilder: (context, index) {
                  final facility = facilities[index];
                  return GestureDetector(
                    onTap: () {
                      // 詳細画面へ遷移
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FacilityDetailScreen(
                            facility: facility,
                          ),
                        ),
                      );
                    },
                    child: Card(
                      margin: const EdgeInsets.symmetric(
                          vertical: 12.0, horizontal: 16.0),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            facility['image'] != null
                                ? Image.network(
                                    facility['image'],
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(Icons.image, size: 80),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    facility['name'] ?? '施設名なし',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '利用金額: ${facility['price']}円',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
