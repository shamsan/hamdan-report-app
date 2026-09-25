import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/utils/responsive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../state/branding_provider.dart';
import '../../core/widgets/yemeni_phone_field.dart';

class BrandingScreen extends ConsumerStatefulWidget {
  const BrandingScreen({super.key});

  @override
  ConsumerState<BrandingScreen> createState() => _BrandingScreenState();
}

class _BrandingScreenState extends ConsumerState<BrandingScreen> {
  late TextEditingController _nameController;
  late TextEditingController _subTitleController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _contractorNameArController;
  late TextEditingController _contractorSubtitleArController;
  late TextEditingController _contractorNameEnController;
  late TextEditingController _ministryNameArController;
  late TextEditingController _ministryNameEnController;
  late TextEditingController _rightLogoNameArController;
  late TextEditingController _rightLogoNameEnController;

  @override
  void initState() {
    super.initState();
    final b = ref.read(brandingProvider);
    _nameController = TextEditingController(
      text: (b.name.isEmpty ||
              b.name == 'مؤسسة الطاقة المتجددة' ||
              b.name == 'مشروع الطاقة المتجددة لدعم الخدمات الصحية' ||
              b.name == 'مكتب الأمم المتحدة لخدمات المشاريع ووزارة الصحة' ||
              b.name.contains('الإتقان') ||
              b.name.contains('الاتقان'))
          ? 'مكتب الأتقان الهندسي للخدمات الهندسية وحلول الطاقة'
          : b.name,
    );
    _subTitleController = TextEditingController(
      text: (b.subTitle.isEmpty ||
              b.subTitle == 'إدارة الصيانة والتشغيل للطاقة المتجددة' ||
              b.subTitle == 'إدارة الصيانة والتشغيل')
          ? 'للخدمات الهندسية وحلول الطاقة'
          : b.subTitle,
    );
    _phoneController = TextEditingController(text: b.contactPhone);
    _emailController = TextEditingController(text: b.contactEmail);
    _addressController = TextEditingController(text: b.address);
    _contractorNameArController = TextEditingController(
      text: (b.contractorNameAr.isEmpty ||
              b.contractorNameAr.contains('بندر ناجي') ||
              b.contractorNameAr.contains('الإتقان') ||
              b.contractorNameAr.contains('الاتقان') ||
              b.contractorNameAr.contains('الأتقان'))
          ? 'مكتب الأتقان الهندسي للخدمات الهندسية وحلول الطاقة'
          : b.contractorNameAr,
    );
    _contractorSubtitleArController = TextEditingController(text: b.contractorSubtitleAr);
    _contractorNameEnController = TextEditingController(
      text: (b.contractorNameEn.isEmpty ||
              b.contractorNameEn.contains('Bandar Naji') ||
              b.contractorNameEn.contains('Al-Etqan') ||
              b.contractorNameEn.contains('Al-Itqan') ||
              b.contractorNameEn.contains('Al-Handasi'))
          ? 'Al-Etqan Engineering Office for Engineering Services and Energy Solutions'
          : b.contractorNameEn,
    );
    _ministryNameArController = TextEditingController(text: b.ministryNameAr);
    _ministryNameEnController = TextEditingController(text: b.ministryNameEn);
    _rightLogoNameArController = TextEditingController(text: b.rightLogoNameAr);
    _rightLogoNameEnController = TextEditingController(text: b.rightLogoNameEn);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subTitleController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _contractorNameArController.dispose();
    _contractorSubtitleArController.dispose();
    _contractorNameEnController.dispose();
    _ministryNameArController.dispose();
    _ministryNameEnController.dispose();
    _rightLogoNameArController.dispose();
    _rightLogoNameEnController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo(int logoSlot) async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (res != null && res.files.isNotEmpty && res.files.first.bytes != null) {
        final b64 = base64Encode(res.files.first.bytes!);
        final cur = ref.read(brandingProvider);
        if (logoSlot == 1) {
          await ref.read(brandingProvider.notifier).updateProfile(cur.copyWith(facilityLogoBase64: b64));
        } else if (logoSlot == 2) {
          await ref.read(brandingProvider.notifier).updateProfile(cur.copyWith(unopsLogoBase64: b64));
        } else if (logoSlot == 3) {
          await ref.read(brandingProvider.notifier).updateProfile(cur.copyWith(contractorLogoBase64: b64));
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تحديث الشعار بنجاح')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل الشعار: $e')),
        );
      }
    }
  }

  Future<void> _resetLogo(int logoSlot) async {
    final cur = ref.read(brandingProvider);
    if (logoSlot == 1) {
      await ref.read(brandingProvider.notifier).updateProfile(cur.copyWith(clearFacilityLogo: true));
    } else if (logoSlot == 2) {
      await ref.read(brandingProvider.notifier).updateProfile(cur.copyWith(clearUnopsLogo: true));
    } else if (logoSlot == 3) {
      await ref.read(brandingProvider.notifier).updateProfile(cur.copyWith(clearContractorLogo: true));
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم استعادة الشعار الافتراضي بنجاح')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final branding = ref.watch(brandingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الهوية المؤسسية والشعارات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'حفظ التغييرات',
            onPressed: () async {
              await ref.read(brandingProvider.notifier).updateProfile(
                branding.copyWith(
                  name: _nameController.text.trim(),
                  subTitle: _subTitleController.text.trim(),
                  contactPhone: _phoneController.text.trim(),
                  contactEmail: _emailController.text.trim(),
                  address: _addressController.text.trim(),
                  contractorNameAr: _contractorNameArController.text.trim(),
                  contractorSubtitleAr: _contractorSubtitleArController.text.trim(),
                  contractorNameEn: _contractorNameEnController.text.trim(),
                  ministryNameAr: _ministryNameArController.text.trim(),
                  ministryNameEn: _ministryNameEnController.text.trim(),
                  rightLogoNameAr: _rightLogoNameArController.text.trim(),
                  rightLogoNameEn: _rightLogoNameEnController.text.trim(),
                ),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم حفظ بيانات الهوية المؤسسية والشعارات بنجاح')),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: AdaptiveContentContainer(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logos Management Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderSubtle, width: 1),
                  boxShadow: AppTheme.cardShadow,
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.photo_library_outlined, color: AppTheme.primaryNavy, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Text('الشعارات الرسمية في ترويسة التقارير (3 شعارات)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.textDark)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('تظهر هذه الشعارات الثلاثة أعلى جميع صفحات التقارير المصدّرة. يمكنك تغيير أي شعار أو استعادة الافتراضي بنقرة زر.', style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _buildLogoSlot(
                          label: 'شعار المرفق / الوزارة',
                          base64: branding.facilityLogoBase64,
                          asset: branding.facilityLogoAsset,
                          onPick: () => _pickLogo(1),
                          onReset: () => _resetLogo(1),
                        ),
                        const SizedBox(width: 8),
                        _buildLogoSlot(
                          label: 'شعار الممول (UNOPS)',
                          base64: branding.unopsLogoBase64,
                          asset: branding.unopsLogoAsset,
                          onPick: () => _pickLogo(2),
                          onReset: () => _resetLogo(2),
                        ),
                        const SizedBox(width: 8),
                        _buildLogoSlot(
                          label: 'شعار المقاول المنفذ',
                          base64: branding.contractorLogoBase64,
                          asset: branding.contractorLogoAsset,
                          onPick: () => _pickLogo(3),
                          onReset: () => _resetLogo(3),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Contractor Info Card (Text under contractor logo)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderSubtle, width: 1),
                  boxShadow: AppTheme.cardShadow,
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.business_rounded, color: AppTheme.primaryNavy, size: 20),
                        const SizedBox(width: 8),
                        const Text('بيانات المقاول المنفذ (تظهر تحت شعار المقاول)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text('هذه النصوص تظهر أسفل شعار المقاول في ترويسة كل صفحة من صفحات التقرير.', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _contractorNameEnController,
                      textDirection: TextDirection.ltr,
                      minLines: 1,
                      maxLines: 3,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        labelText: 'اسم المقاول بالإنجليزي (يظهر أولاً بالأسود)',
                        hintText: 'e.g. Al-Etqan Engineering Office for Engineering Services and Energy Solutions',
                        prefixIcon: Icon(Icons.language_rounded, size: 18),
                        helperText: 'يدعم 1 أو 2 أو 3 أسطر (اضغط Enter للتقسيم اليدوي)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _contractorNameArController,
                      minLines: 1,
                      maxLines: 3,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        labelText: 'اسم المقاول بالعربي (يظهر ثانياً بالأزرق)',
                        hintText: 'مثال: مكتب الأتقان الهندسي للخدمات الهندسية وحلول الطاقة',
                        prefixIcon: Icon(Icons.badge_outlined, size: 18),
                        helperText: 'يدعم 1 أو 2 أو 3 أسطر (اضغط Enter للتقسيم اليدوي)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _contractorSubtitleArController,
                      decoration: const InputDecoration(
                        labelText: 'المسمى الفرعي أو التجاري بالعربي (اختياري)',
                        hintText: 'مثال: للخدمات الهندسية وحلول الطاقة',
                        prefixIcon: Icon(Icons.subtitles_outlined, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

            // Ministry & Entity Card (Middle Emblem)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderSubtle, width: 1),
                boxShadow: AppTheme.cardShadow,
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.account_balance_rounded, color: AppTheme.primaryNavy, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text('الجهة المالكة والوزارة (الشعار الأوسط)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.textDark)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _ministryNameEnController,
                    textDirection: TextDirection.ltr,
                    minLines: 1,
                    maxLines: 3,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      labelText: 'اسم الوزارة بالإنجليزي (يظهر أولاً بالأسود)',
                      hintText: 'e.g. Ministry of Education / Ministry of Public Health',
                      prefixIcon: Icon(Icons.language_rounded, size: 18),
                      helperText: 'يدعم 1 أو 2 أو 3 أسطر (اضغط Enter للتقسيم اليدوي)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ministryNameArController,
                    minLines: 1,
                    maxLines: 3,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      labelText: 'اسم الوزارة بالعربي (يظهر ثانياً بالأزرق)',
                      hintText: 'مثال: وزارة التربية والتعليم أو وزارة الصحة العامة والسكان',
                      prefixIcon: Icon(Icons.domain_rounded, size: 18),
                      helperText: 'يدعم 1 أو 2 أو 3 أسطر (اضغط Enter للتقسيم اليدوي)',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Right Logo & Funder Card (UNOPS / Alternative Funder)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderSubtle, width: 1),
                boxShadow: AppTheme.cardShadow,
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.brandCyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.verified_outlined, color: AppTheme.brandCyan, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'الجهة الممولة / الشعار الأيمن (UNOPS أو جهة بديلة)',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.textDark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: AppTheme.brandCyan,
                      title: const Text(
                        'إظهار الشعار الأيمن في ترويسة التقارير',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                      ),
                      subtitle: const Text(
                        'عند إلغاء هذا الخيار، سيظهر الشعاران الآخران فقط، وينتقل شعار الوزارة إلى اليمين مكان الشعار الملغي.',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                      value: branding.showRightLogo,
                      onChanged: (val) {
                        ref.read(brandingProvider.notifier).updateProfile(
                          branding.copyWith(showRightLogo: val),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: branding.showRightLogo
                          ? AppTheme.brandCyan.withValues(alpha: 0.06)
                          : Colors.orange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: branding.showRightLogo
                            ? AppTheme.brandCyan.withValues(alpha: 0.2)
                            : Colors.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          branding.showRightLogo ? Icons.info_outline : Icons.swap_horiz_rounded,
                          size: 18,
                          color: branding.showRightLogo ? AppTheme.brandCyan : Colors.deepOrange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            branding.showRightLogo
                                ? 'الترويسة الحالية: (أيسر: المقاول • أوسط: الوزارة • أيمن: الشعار الأيمن)'
                                : 'الترويسة الحالية: (أيسر: المقاول • أيمن: الوزارة تلقائياً مكان الشعار الملغي)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: branding.showRightLogo ? AppTheme.primaryNavy : Colors.deepOrange.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (branding.showRightLogo) ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _rightLogoNameEnController,
                      textDirection: TextDirection.ltr,
                      minLines: 1,
                      maxLines: 3,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        labelText: 'اسم الجهة بالإنجليزي (يظهر أولاً بالأسود)',
                        hintText: 'e.g. UNITED NATIONS OFFICE FOR PROJECT SERVICES (UNOPS)',
                        prefixIcon: Icon(Icons.language_rounded, size: 18),
                        helperText: 'يدعم 1 أو 2 أو 3 أسطر (اضغط Enter للتقسيم اليدوي)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _rightLogoNameArController,
                      minLines: 1,
                      maxLines: 3,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        labelText: 'اسم الجهة بالعربي (يظهر ثانياً بالأزرق)',
                        hintText: 'مثال: مكتب الأمم المتحدة لخدمات المشاريع',
                        prefixIcon: Icon(Icons.badge_outlined, size: 18),
                        helperText: 'يدعم 1 أو 2 أو 3 أسطر (اضغط Enter للتقسيم اليدوي)',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Corporate Colors Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderSubtle, width: 1),
                boxShadow: AppTheme.cardShadow,
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.palette_outlined, color: AppTheme.primaryNavy, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text('الألوان المؤسسية للتقارير والواجهة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.textDark)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('اللون الرئيسي المعتمد للهيدر والعناصر البارزة:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      0xFF1565C0, // Navy Blue
                      0xFF0D47A1, // Deep Blue
                      0xFF00695C, // Dark Teal
                      0xFF2E7D32, // Forest Green
                      0xFF37474F, // Slate Grey
                    ].map((c) {
                      final isSelected = branding.primaryColorValue == c;
                      return GestureDetector(
                        onTap: () => ref.read(brandingProvider.notifier).updateColors(primaryColor: c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Color(c) : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: Color(c),
                            child: isSelected
                                ? const Icon(Icons.check, color: Colors.white, size: 16)
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Organization Info Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderSubtle, width: 1),
                boxShadow: AppTheme.cardShadow,
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.contact_mail_outlined, color: AppTheme.primaryNavy, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text('بيانات التواصل والتذييل المؤسسي', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.textDark)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم المؤسسة / الهيئة',
                      prefixIcon: Icon(Icons.apartment_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _subTitleController,
                    decoration: const InputDecoration(
                      labelText: 'الوصف أو المسمى الفرعي',
                      prefixIcon: Icon(Icons.description_outlined, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  YemeniPhoneField(
                    controller: _phoneController,
                    label: 'رقم الهاتف المعتمد',
                    hint: '777 123 456',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني الرسمي',
                      prefixIcon: Icon(Icons.email_outlined, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'العنوان الرسمي',
                      prefixIcon: Icon(Icons.location_on_outlined, size: 18),
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

  Widget _buildLogoSlot({
    required String label,
    required String? base64,
    required String asset,
    required VoidCallback onPick,
    required VoidCallback onReset,
  }) {
    final isCustom = base64 != null && base64.isNotEmpty;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isCustom ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isCustom ? const Color(0xFF3B82F6) : const Color(0xFFCBD5E1)),
        ),
        child: Column(
          children: [
            Container(
              height: 55,
              width: double.infinity,
              alignment: Alignment.center,
              child: isCustom
                  ? Image.memory(base64Decode(base64), fit: BoxFit.contain)
                  : Image.asset(asset, fit: BoxFit.contain),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 1),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isCustom ? const Color(0xFFDBEAFE) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isCustom ? 'شعار مخصص' : 'شعار افتراضي',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: isCustom ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                  icon: const Icon(Icons.upload, size: 13),
                  label: const Text('تغيير', style: TextStyle(fontSize: 11)),
                  onPressed: onPick,
                ),
                if (isCustom)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.refresh, size: 16, color: Colors.red),
                    tooltip: 'استعادة الافتراضي',
                    onPressed: onReset,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
