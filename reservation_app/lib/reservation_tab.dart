import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'facility_detail_screen.dart';

class ReservationTab extends StatelessWidget {
  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;

  FirebaseAuth get auth => _auth ?? FirebaseAuth.instance;
  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  const ReservationTab({
    super.key,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth,
        _firestore = firestore;

  Future<Map<String, String>?> _getUserApartmentInfo() async {
    final user = auth.currentUser;
    if (user == null) return null;

    final userDoc = await firestore.collection('users').doc(user.uid).get();
    final apartmentId = userDoc.data()?['apartment'] as String?;
    if (apartmentId == null || apartmentId.isEmpty) return null;

    final apartmentDoc =
        await firestore.collection('apartments').doc(apartmentId).get();
    final apartmentName =
        apartmentDoc.data()?['name']?.toString().trim().isNotEmpty == true
            ? apartmentDoc.data()!['name'].toString().trim()
            : 'マンション共用施設';

    return {
      'id': apartmentId,
      'name': apartmentName,
    };
  }

  Future<List<Map<String, dynamic>>> _getFacilities(String apartmentId) async {
    final querySnapshot = await firestore
        .collection('facilities')
        .where('apartment_id', isEqualTo: apartmentId)
        .get();

    return querySnapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList()
      ..sort((a, b) => (a['name'] ?? '').toString().compareTo(
            (b['name'] ?? '').toString(),
          ));
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF7F9FB);
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: FutureBuilder<Map<String, String>?>(
          future: _getUserApartmentInfo(),
          builder: (context, apartmentSnapshot) {
            if (apartmentSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (apartmentSnapshot.hasError ||
                apartmentSnapshot.data == null ||
                apartmentSnapshot.data!['id'] == null ||
                apartmentSnapshot.data!['id']!.isEmpty) {
              return const _ReservationErrorState(
                message: '施設情報の取得に失敗しました。',
              );
            }

            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _getFacilities(apartmentSnapshot.data!['id']!),
              builder: (context, facilitySnapshot) {
                if (facilitySnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (facilitySnapshot.hasError) {
                  return const _ReservationErrorState(
                    message: '施設一覧の取得に失敗しました。',
                  );
                }

                final facilities = facilitySnapshot.data ?? [];
                if (facilities.isEmpty) {
                  return const _ReservationEmptyState(
                    title: '予約できる施設がありません',
                    description: 'マンションに紐づく共用施設が見つかりませんでした。',
                  );
                }

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _ReservationHero(
                          totalCount: facilities.length,
                          apartmentName: apartmentSnapshot.data!['name']!,
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                      sliver: SliverList.separated(
                        itemCount: facilities.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final facility = facilities[index];
                          return _FacilityCard(
                            facility: facility,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => FacilityDetailScreen(
                                    facility: facility,
                                    firestore: firestore,
                                    auth: auth,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ReservationHero extends StatelessWidget {
  final int totalCount;
  final String apartmentName;

  const _ReservationHero({
    required this.totalCount,
    required this.apartmentName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F7FF), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14004D64),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            apartmentName,
            style: const TextStyle(
              color: Color(0xFF004D64),
              fontSize: 30,
              height: 1.1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '快適な共用施設を選んで、すぐに予約できます。空き状況は詳細画面からそのまま確認できます。',
            style: TextStyle(
              color: Color(0xFF52616B),
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(Icons.apartment_rounded,
                  color: Color(0xFF004D64), size: 18),
              const SizedBox(width: 8),
              Text(
                '$totalCount 件の施設を表示中',
                style: const TextStyle(
                  color: Color(0xFF004D64),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FacilityCard extends StatelessWidget {
  final Map<String, dynamic> facility;
  final VoidCallback onTap;

  const _FacilityCard({
    required this.facility,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = facility['image']?.toString();
    final priceLabel = _buildPriceText(facility);
    final subtitle = facility['description']?.toString().trim().isNotEmpty == true
        ? facility['description'].toString().trim()
        : '空き時間を確認して、そのまま予約できます。';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 30,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const _FacilityImagePlaceholder(),
                        )
                      : const _FacilityImagePlaceholder(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            facility['name']?.toString() ?? '施設名なし',
                            style: const TextStyle(
                              color: Color(0xFF191C1D),
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF5E6C76),
                              fontSize: 13,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD8ECF7),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.payments_outlined,
                                      size: 16,
                                      color: Color(0xFF33515F),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      priceLabel,
                                      style: const TextStyle(
                                        color: Color(0xFF33515F),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4F7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF42525C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _buildPriceText(Map<String, dynamic> facility) {
    final formatter = NumberFormat.decimalPattern('ja_JP');
    final rawPrice = facility['price'];
    final price = rawPrice is num
        ? formatter.format(rawPrice)
        : formatter.format(num.tryParse(rawPrice?.toString() ?? '') ?? 0);

    final unitTime = facility['unitTime'];
    if (unitTime is Map) {
      final value = unitTime['value'];
      final unit = switch (unitTime['unit']) {
        'min' => '分',
        'h' => '時間',
        'day' => '日',
        _ => '',
      };
      if (value != null && unit.isNotEmpty) {
        return '$value$unit $price円';
      }
    }

    return '$price円';
  }
}

class _FacilityImagePlaceholder extends StatelessWidget {
  const _FacilityImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFBFE4F7), Color(0xFFEFF6FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.meeting_room_rounded,
          size: 54,
          color: Color(0xFF4C6A78),
        ),
      ),
    );
  }
}

class _ReservationErrorState extends StatelessWidget {
  final String message;

  const _ReservationErrorState({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 56, color: Color(0xFF7A8B95)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF31424D),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ReservationEmptyState extends StatelessWidget {
  final String title;
  final String description;

  const _ReservationEmptyState({
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.apartment_outlined,
                size: 56, color: Color(0xFF7A8B95)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF1F2A30),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF5F6D77),
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
