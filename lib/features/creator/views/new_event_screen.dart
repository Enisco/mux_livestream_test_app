import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/creator/repo/creator_repo.dart';
import 'package:test_app/features/creator/repo/event_repo.dart';
import 'package:test_app/features/creator/services/creator_image_picker.dart';
import 'package:test_app/features/creator/views/widgets/creator_onboarding_parts.dart';
import 'package:test_app/features/creator/views/widgets/creator_setup_fields.dart';
import 'package:test_app/features/creator/views/widgets/creator_topics_sheet.dart';
import 'package:test_app/features/creator/views/widgets/go_live_sheet.dart';
import 'package:test_app/features/creator/views/widgets/moment_picker.dart';
import 'package:test_app/features/creator/views/widgets/new_event_parts.dart';
import 'package:test_app/features/creator/views/widgets/new_media_parts.dart';
import 'package:test_app/models/creator_models/creator_models.dart';
import 'package:test_app/models/creator_models/event_draft_models.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

/// Putting a service or gathering on the calendar.
///
/// Nothing here is uploaded or transcoded — an event lives in the content
/// service and is only ever text, a cover image and a moment. That is why
/// it does not go through [MediaUploadRepo] and has no upload progress.
///
/// Two things the design asks for cannot be built, and are left out rather
/// than faked: a map preview (the API stores no coordinates, and the app
/// has no maps or geocoding) and "Add to series" (events have no series
/// field under any name). Two more are added because publishing is refused
/// without them: a street address with a city, and a meeting link.
class NewEventScreen extends StatefulWidget {
  const NewEventScreen({super.key, this.creatorId, this.events, this.creators});

  /// Defaults to the signed-in creator.
  final String? creatorId;

  /// Both default to the real thing; a test supplies its own.
  final EventRepo? events;
  final CreatorRepo? creators;

  @override
  State<NewEventScreen> createState() => _NewEventScreenState();
}

class _NewEventScreenState extends State<NewEventScreen> {
  late final _repo = widget.events ?? EventRepo();
  late final _creators = widget.creators ?? CreatorRepo();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _venueController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _meetingUrlController = TextEditingController();
  final _capacityController = TextEditingController();

  EventVenueType _venueType = EventVenueType.physical;

  /// Defaults to the next round hour, so a creator who changes nothing
  /// still files something coherent.
  late DateTime _startAt = _nextHour();
  DateTime? _endDate;

  /// An IANA name such as `Africa/Lagos`. `schedule.timezone` is required
  /// and validated, so this is read from the device rather than guessed
  /// from the UTC offset — many zones share one.
  String _timezone = 'UTC';

  PickedImage? _cover;
  String? _coverFileId;

  bool _rsvp = true;
  String _visibility = 'public';

  List<ContentCategory> _categories = const [];
  Set<String> _chosenCategories = {};

  bool _working = false;

  String? get _creatorId => widget.creatorId ?? LocalStorage.creatorId;

  static DateTime _nextHour() {
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
    ).add(const Duration(hours: 1));
  }

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _titleController,
      _descriptionController,
      _addressController,
      _cityController,
      _meetingUrlController,
    ]) {
      controller.addListener(_onTyped);
    }
    _loadCategories();
    _loadTimezone();
  }

  void _onTyped() => setState(() {});

  @override
  void dispose() {
    for (final controller in [
      _titleController,
      _descriptionController,
      _addressController,
      _cityController,
      _meetingUrlController,
    ]) {
      controller.removeListener(_onTyped);
    }
    _titleController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _meetingUrlController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _loadTimezone() async {
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      if (!mounted || zone.identifier.isEmpty) return;
      setState(() => _timezone = zone.identifier);
    } catch (e) {
      // UTC is a name the API accepts, so a failure here still files a
      // valid event — it just reads in the wrong zone.
      logger.w('Could not read the device timezone', error: e);
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _creators.fetchCategories();
      if (!mounted || categories.isEmpty) return;
      setState(() => _categories = categories);
    } catch (e) {
      logger.w('Could not load categories', error: e);
    }
  }

  // ---- what the API will take --------------------------------------------

  EventDraft get _draft => EventDraft(
    title: _titleController.text.trim(),
    description: _descriptionController.text.trim(),
    categorySlugs: _chosenCategories.toList(growable: false),
    venueType: _venueType,
    startAt: _startAt,
    endAt: _endDate == null
        ? null
        : DateTime(
            _endDate!.year,
            _endDate!.month,
            _endDate!.day,
            _startAt.hour,
            _startAt.minute,
          ),
    timezone: _timezone,
    location: EventLocation(
      label: _venueController.text.trim(),
      addressLine: _addressController.text.trim(),
      city: _cityController.text.trim(),
      meetingUrl: _meetingUrlController.text.trim(),
    ),
    rsvpRequired: _rsvp,
    capacity: int.tryParse(_capacityController.text.trim()),
    visibility: _visibility,
    coverImageFileId: _coverFileId,
  );

  /// A title and a start are all the API needs to file a draft.
  bool get _canSave => _titleController.text.trim().isNotEmpty;

  /// Publishing asks for more, and the check mirrors the API's own.
  bool get _canPublish => _canSave && _draft.publishBlock == null;

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppStyles.body(13)),
        backgroundColor: AppColors.neutral800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ---- the fields --------------------------------------------------------

  Future<void> _pickCover() async {
    final result = await CreatorImagePicker.pick(
      maxBytes: EventRepo.coverMaxBytes,
    );
    if (!mounted || result.isCancelled) return;

    switch (result.failure) {
      case PickFailure.tooLarge:
        _say(AppStrings.newEventCoverTooLarge);
      case PickFailure.unreadable:
      case PickFailure.unsupported:
        _say(AppStrings.newMediaThumbUnreadable);
      case null:
        setState(() {
          _cover = result.image;
          _coverFileId = null;
        });
    }
  }

  Future<void> _pickCategories() async {
    final picked = await CreatorTopicsSheet.show(
      context,
      categories: _categories,
      selected: _chosenCategories,
    );
    if (!mounted || picked == null) return;
    if (picked.length > 8) {
      _say(AppStrings.newMediaCategoryMax);
      return;
    }
    setState(() => _chosenCategories = picked);
  }

  String get _categoryValue => [
    for (final slug in _chosenCategories)
      _categories.where((c) => c.slug == slug).map((c) => c.name).firstOrNull ??
          slug,
  ].join(', ');

  Future<void> _pickStart({required bool dateOnly}) async {
    final picked = await pickMoment(
      context,
      initial: _startAt,
      dateOnly: dateOnly,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _startAt = mergeMoment(_startAt, picked, dateOnly: dateOnly);
      // An end that now falls before the start would be refused as an
      // "Invalid schedule", so it gives way.
      if (_endDate != null && _endDate!.isBefore(_dayOf(_startAt))) {
        _endDate = null;
      }
    });
  }

  Future<void> _pickEnd() async {
    final picked = await pickMoment(
      context,
      initial: _endDate ?? _startAt,
      dateOnly: true,
      minimum: _dayOf(_startAt),
    );
    if (picked == null || !mounted) return;
    setState(() => _endDate = _dayOf(picked));
  }

  static DateTime _dayOf(DateTime at) => DateTime(at.year, at.month, at.day);

  Future<void> _pickVisibility() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.base2,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (slug, label) in const [
              ('public', AppStrings.contentPublic),
              ('unlisted', AppStrings.contentUnlisted),
              ('private', AppStrings.contentPrivate),
            ])
              ListTile(
                key: ValueKey('event-visibility-$slug'),
                title: Text(label, style: AppStyles.label(14)),
                trailing: _visibility == slug
                    ? const Icon(Icons.check, color: AppColors.brandPrimary)
                    : null,
                onTap: () => Navigator.pop(sheetContext, slug),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _visibility = picked);
  }

  // ---- filing it ---------------------------------------------------------

  Future<void> _publish() => _commit(publish: true);

  Future<void> _saveDraft() => _commit(publish: false);

  Future<void> _commit({required bool publish}) async {
    final creatorId = _creatorId;
    if (creatorId == null) return _say(AppStrings.newMediaRejected);

    final capacity = _capacityController.text.trim();
    if (_rsvp && capacity.isNotEmpty && (int.tryParse(capacity) ?? 0) < 1) {
      return _say(AppStrings.newEventCapacityFloor);
    }

    setState(() => _working = true);
    try {
      _coverFileId ??= _cover == null
          ? null
          : await _repo.uploadCover(creatorId: creatorId, image: _cover!);

      final id = await _repo.create(creatorId: creatorId, draft: _draft);
      if (publish) await _repo.publish(id);

      if (!mounted) return;
      setState(() => _working = false);
      await PublishedCard.show(
        context,
        title: publish
            ? AppStrings.newEventLiveTitle
            : AppStrings.newMediaDraftTitle,
        body: publish
            ? AppStrings.newEventLiveBody
            : AppStrings.newEventDraftBody,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on EventException catch (e) {
      if (!mounted) return;
      setState(() => _working = false);
      _say(_wording(e));
    }
  }

  static String _wording(EventException e) => switch (e.failure) {
    EventFailure.needsDescription => AppStrings.newEventNeedsDescription,
    EventFailure.needsAddress => AppStrings.newEventNeedsAddress,
    EventFailure.needsMeetingUrl => AppStrings.newEventNeedsMeetingUrl,
    EventFailure.badSchedule => AppStrings.newEventBadSchedule,
    EventFailure.network => AppStrings.newMediaNetwork,
    EventFailure.rejected => e.message ?? AppStrings.newMediaRejected,
  };

  // ---- the screen --------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final physical = _venueType.needsAddress;
    final virtual = _venueType.needsMeetingUrl;

    return Scaffold(
      backgroundColor: AppColors.base1,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20.s, 8.s, 20.s, 0),
              child: const CreatorFlowHeader(
                title: AppStrings.newEventTitle,
                subtitle: AppStrings.newEventSubtitle,
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(20.s, 18.s, 20.s, 20.s),
                children: [
                  const RequiredLabel(
                    AppStrings.newEventCover,
                    required: false,
                  ),
                  SizedBox(height: 8.s),
                  ThumbnailWell(image: _cover, onPick: _pickCover),
                  SizedBox(height: 18.s),

                  const RequiredLabel(AppStrings.newEventTitleLabel),
                  SizedBox(height: 8.s),
                  CreatorTextField(
                    key: const ValueKey('event-title'),
                    controller: _titleController,
                    hint: AppStrings.newEventTitleHint,
                  ),
                  SizedBox(height: 18.s),

                  const RequiredLabel(AppStrings.newMediaDescriptionLabel),
                  SizedBox(height: 8.s),
                  CreatorTextField(
                    key: const ValueKey('event-description'),
                    controller: _descriptionController,
                    hint: AppStrings.newMediaDescriptionHint,
                    maxLines: 4,
                  ),
                  SizedBox(height: 18.s),

                  const RequiredLabel(
                    AppStrings.newMediaCategoryLabel,
                    required: false,
                  ),
                  SizedBox(height: 8.s),
                  CreatorSelectField(
                    key: const ValueKey('event-category'),
                    hint: AppStrings.newMediaCategoryHint,
                    value: _categoryValue.isEmpty ? null : _categoryValue,
                    onTap: _pickCategories,
                  ),
                  SizedBox(height: 18.s),

                  const RequiredLabel(AppStrings.newEventType, required: false),
                  SizedBox(height: 8.s),
                  EventTypeCards(
                    selected: _venueType,
                    onSelected: (type) => setState(() => _venueType = type),
                  ),
                  SizedBox(height: 18.s),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const RequiredLabel(
                              AppStrings.newEventStartDate,
                              required: false,
                            ),
                            SizedBox(height: 8.s),
                            PickerField(
                              fieldKey: const ValueKey('event-start-date'),
                              value: formatSheetDate(_startAt),
                              hint: '',
                              onTap: () => _pickStart(dateOnly: true),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12.s),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const RequiredLabel(
                              AppStrings.newEventEndDate,
                              required: false,
                            ),
                            SizedBox(height: 8.s),
                            PickerField(
                              fieldKey: const ValueKey('event-end-date'),
                              value: _endDate == null
                                  ? ''
                                  : formatSheetDate(_endDate!),
                              hint: AppStrings.newEventEndDate,
                              onTap: _pickEnd,
                              onClear: () => setState(() => _endDate = null),
                            ),
                            const FieldNote(AppStrings.newEventNoEndDate),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 18.s),

                  const RequiredLabel(AppStrings.newEventTime, required: false),
                  SizedBox(height: 8.s),
                  PickerField(
                    fieldKey: const ValueKey('event-time'),
                    value: formatSheetTime(_startAt),
                    hint: '',
                    onTap: () => _pickStart(dateOnly: false),
                  ),
                  FieldNote(_zoneNote),
                  SizedBox(height: 18.s),

                  if (physical) ...[
                    const RequiredLabel(
                      AppStrings.newEventLocation,
                      required: false,
                    ),
                    SizedBox(height: 8.s),
                    CreatorTextField(
                      key: const ValueKey('event-venue'),
                      controller: _venueController,
                      hint: AppStrings.newEventLocationHint,
                    ),
                    SizedBox(height: 18.s),
                    const RequiredLabel(AppStrings.newEventAddress),
                    SizedBox(height: 8.s),
                    CreatorTextField(
                      key: const ValueKey('event-address'),
                      controller: _addressController,
                      hint: AppStrings.newEventAddressHint,
                    ),
                    SizedBox(height: 18.s),
                    const RequiredLabel(AppStrings.newEventCity),
                    SizedBox(height: 8.s),
                    CreatorTextField(
                      key: const ValueKey('event-city'),
                      controller: _cityController,
                      hint: AppStrings.newEventCityHint,
                    ),
                    SizedBox(height: 18.s),
                  ],

                  if (virtual) ...[
                    const RequiredLabel(AppStrings.newEventMeetingUrl),
                    SizedBox(height: 8.s),
                    CreatorTextField(
                      key: const ValueKey('event-meeting-url'),
                      controller: _meetingUrlController,
                      hint: AppStrings.newEventMeetingUrlHint,
                      keyboardType: TextInputType.url,
                    ),
                    SizedBox(height: 18.s),
                  ],

                  SwitchRow(
                    rowKey: const ValueKey('event-rsvp'),
                    title: AppStrings.newEventRsvp,
                    body: AppStrings.newEventRsvpBody,
                    value: _rsvp,
                    onChanged: (on) => setState(() => _rsvp = on),
                  ),
                  if (_rsvp) ...[
                    SizedBox(height: 18.s),
                    const RequiredLabel(
                      AppStrings.newEventCapacity,
                      required: false,
                    ),
                    SizedBox(height: 8.s),
                    CreatorTextField(
                      key: const ValueKey('event-capacity'),
                      controller: _capacityController,
                      hint: AppStrings.newEventCapacityHint,
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  SizedBox(height: 18.s),

                  const RequiredLabel(
                    AppStrings.newEventVisibility,
                    required: false,
                  ),
                  SizedBox(height: 8.s),
                  CreatorSelectField(
                    key: const ValueKey('event-visibility'),
                    hint: AppStrings.contentPublic,
                    value: switch (_visibility) {
                      'unlisted' => AppStrings.contentUnlisted,
                      'private' => AppStrings.contentPrivate,
                      _ => AppStrings.contentPublic,
                    },
                    onTap: _pickVisibility,
                  ),
                ],
              ),
            ),
            _actions(context),
          ],
        ),
      ),
    );
  }

  /// "Times are read in Africa/Lagos (GMT+1)" — the design names the zone,
  /// and the API needs it to be a real one.
  String get _zoneNote {
    final offset = DateTime.now().timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs();
    final minutes = offset.inMinutes.abs().remainder(60);
    final clock = minutes == 0 ? '$hours' : '$hours:$minutes';
    return '$_timezone (GMT$sign$clock)';
  }

  Widget _actions(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      20.s,
      12.s,
      20.s,
      12.s + MediaQuery.paddingOf(context).bottom,
    ),
    decoration: const BoxDecoration(
      color: AppColors.base1,
      border: Border(top: BorderSide(color: AppColors.neutral900)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PrimaryButton(
          key: const ValueKey('event-publish'),
          label: AppStrings.newEventPublish,
          height: 52.s,
          enabled: _canPublish,
          loading: _working,
          onPressed: _publish,
        ),
        if (_canSave && !_canPublish) ...[
          SizedBox(height: 8.s),
          Text(
            switch (_draft.publishBlock) {
              EventPublishBlock.description =>
                AppStrings.newEventNeedsDescription,
              EventPublishBlock.address => AppStrings.newEventNeedsAddress,
              EventPublishBlock.meetingUrl =>
                AppStrings.newEventNeedsMeetingUrl,
              null => '',
            },
            textAlign: TextAlign.center,
            style: AppStyles.label(
              11,
              color: AppColors.neutral500,
              lineHeight: 15 / 11,
            ),
          ),
        ],
        SizedBox(height: 12.s),
        GestureDetector(
          key: const ValueKey('event-draft'),
          behavior: HitTestBehavior.opaque,
          onTap: _canSave && !_working ? _saveDraft : null,
          child: Text(
            AppStrings.newMediaSaveDraft,
            style: AppStyles.label(
              13,
              color: _canSave ? AppColors.neutral200 : AppColors.neutral500,
            ),
          ),
        ),
      ],
    ),
  );
}
