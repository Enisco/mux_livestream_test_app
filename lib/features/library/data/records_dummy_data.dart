import 'package:test_app/models/library_models/library_models.dart';

/// Placeholder rows for My events, prayer requests and testimonies.
///
/// TEMPORARY. None of the three has a route:
///
///  * **Events** — `/v1/discovery/...` lists the platform's events, but
///    nothing records that this reader is going to one, so there is no RSVP to
///    read back.
///  * **Prayer requests** — the design has a submit form elsewhere in the
///    file; the spec has neither a create nor a list route for it.
///  * **Testimonies** — `GET /v1/discovery/creator/{id}/testimonies` returns a
///    *ministry's* wall. Nothing lists the ones a reader submitted, or their
///    review status, which is most of what this screen shows.
///
/// To retire this: delete the file and fix the import errors in
/// `my_events_screen.dart`, `prayer_requests_screen.dart` and
/// `testimonies_screen.dart`.
abstract final class RecordsDummyData {
  static const events = <MyEvent>[
    MyEvent(
      id: 'e1',
      title: 'Youth Conference',
      creatorName: 'CCI International',
      creatorVerified: true,
      day: '12',
      month: 'JUN',
      venue: 'River Worship',
      time: 'Sat 9:00am',
      past: false,
    ),
    MyEvent(
      id: 'e2',
      title: 'Youth Conference',
      creatorName: 'CCI International',
      creatorVerified: true,
      day: '12',
      month: 'JUN',
      venue: 'River Worship',
      time: 'Sat 9:00am',
      past: false,
      going: true,
    ),
    MyEvent(
      id: 'e3',
      title: 'Youth Conference',
      creatorName: 'CCI International',
      creatorVerified: true,
      day: '12',
      month: 'JUN',
      venue: 'River Worship',
      time: 'Sat 9:00am',
      past: true,
    ),
    MyEvent(
      id: 'e4',
      title: 'Night of Worship',
      creatorName: 'Grace Community',
      creatorVerified: true,
      day: '02',
      month: 'MAY',
      venue: 'Grace Auditorium',
      time: 'Fri 6:30pm',
      past: true,
    ),
  ];

  static const eventsTotal = 10;

  static const _prayerBody =
      'Heavenly Father, in moments when shadows seem to stretch endlessly '
      'across our lives, we ask for Your light to shine through. Help us to '
      'pause and recognize the darkest, most challenging parts of our '
      'journey. Grant us the courage and strength to bring those shadows into '
      'Your healing light—a light so powerful that darkness cannot prevail. '
      'Remind us that even in the hardest times, Your unbreakable light '
      'within us is ready to shine forth. Amen.';

  static const prayers = <PrayerRequest>[
    PrayerRequest(
      id: 'p1',
      author: 'Cynthia Morgan',
      authorVerified: true,
      about: 'Walking by faith',
      aboutKind: PrayerAbout.audio,
      body: _prayerBody,
      sharedAgo: '2 days ago',
      status: PrayerStatus.open,
    ),
    PrayerRequest(
      id: 'p2',
      author: 'Marcus Lee',
      authorVerified: true,
      about: 'Embracing growth',
      aboutKind: PrayerAbout.audio,
      body:
          'Dear Creator, guide my steps as I seek to learn and grow from every '
          'experience. Let patience and wisdom be my companions on this '
          'journey. Help me see challenges not as obstacles, but as '
          'opportunities to become the best version of myself. Amen.',
      sharedAgo: '5 hours ago',
      status: PrayerStatus.prayedFor,
    ),
    PrayerRequest(
      id: 'p3',
      author: 'Aisha Khan',
      authorVerified: true,
      about: 'Finding peace within',
      aboutKind: PrayerAbout.video,
      body:
          'Spirit of calm, breathe serenity into my restless heart. Teach me '
          'to embrace stillness amidst chaos and find refuge in quiet '
          'moments. Let peace flow through me, touching those around me with '
          'gentle kindness and understanding. Amen.',
      sharedAgo: 'yesterday',
      status: PrayerStatus.closed,
    ),
    PrayerRequest(
      id: 'p4',
      author: 'Diego Ramirez',
      authorVerified: true,
      about: '',
      aboutKind: PrayerAbout.general,
      body:
          'Infinite Source of knowledge, illuminate my mind and open my heart '
          'to deeper understanding. Grant me clarity to navigate complex '
          'decisions and courage to act with integrity. May wisdom guide my '
          'path today and always. Amen.',
      sharedAgo: '3 days ago',
      status: PrayerStatus.open,
    ),
    PrayerRequest(
      id: 'p5',
      author: 'Lena Sorensen',
      authorVerified: true,
      about: 'Gratitude in every day',
      aboutKind: PrayerAbout.blog,
      body:
          'Gracious light, thank You for the countless blessings often unseen. '
          'Help me to recognize and cherish the small joys and simple gifts '
          'that color my days. May gratitude be the lens through which I view '
          'the world, fostering love and contentment. Amen.',
      sharedAgo: '4 hours ago',
      status: PrayerStatus.prayedFor,
    ),
  ];

  static const _testimonyBody =
      'I initially came to this church as a skeptic, simply to support a '
      'friend who invited me. Over the course of six months attending '
      'services and engaging with the community, I experienced a profound '
      'transformation. Eventually, I gave my life to Christ, and since then, '
      'I have felt an indescribable peace and fulfillment that I never '
      'thought possible. This journey has truly changed my perspective and '
      'brought a deep sense of purpose to my life.';

  static const testimonies = <Testimony>[
    Testimony(
      id: 't1',
      author: 'Cynthia Morgan',
      authorVerified: true,
      submittedAgo: '3 days ago',
      tags: ['Healing', 'Answered prayer'],
      body: _testimonyBody,
      status: TestimonyStatus.pending,
    ),
    Testimony(
      id: 't2',
      author: 'Elena Rodriguez',
      authorVerified: true,
      submittedAgo: 'yesterday',
      tags: ['Joy', 'Renewed happiness'],
      body:
          'Joining this church helped me reconnect with my faith after years '
          'of feeling lost. The warmth and acceptance I found here reignited '
          'a joy in my heart that I hadn\'t felt since childhood.',
      status: TestimonyStatus.approved,
      wall: 'River Worship',
    ),
    Testimony(
      id: 't3',
      author: 'Aisha Patel',
      authorVerified: true,
      submittedAgo: '2 weeks ago',
      tags: ['Faith', 'A new beginning'],
      body:
          'Coming from a background with little religious exposure, '
          'discovering this church opened a door to faith I never imagined. '
          'The guidance and community support have been instrumental in '
          'shaping a new path filled with hope.',
      status: TestimonyStatus.approved,
      wall: 'River Worship',
    ),
    Testimony(
      id: 't4',
      author: 'Marcus Lee',
      authorVerified: true,
      submittedAgo: '1 week ago',
      tags: ['Strength', 'Overcoming adversity'],
      body:
          'After facing numerous challenges in my career and personal life, '
          'finding this community gave me the strength and encouragement I '
          'needed. Through prayer and fellowship, I\'ve rediscovered hope and '
          'resilience, allowing me to overcome obstacles I once thought '
          'insurmountable.',
      status: TestimonyStatus.rejected,
    ),
    Testimony(
      id: 't5',
      author: 'David Kim',
      authorVerified: true,
      submittedAgo: '5 days ago',
      tags: ['Peace', 'Calm in chaos'],
      body:
          'During a tumultuous period in my life, the teachings and prayers at '
          'this church provided me with an anchor. I learned to find peace '
          'amidst the storm, which has profoundly changed how I approach '
          'daily challenges.',
      status: TestimonyStatus.rejected,
    ),
  ];
}
