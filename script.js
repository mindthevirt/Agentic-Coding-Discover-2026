(function () {
  var EVENTS = [
    {
      id: 'oktoberfest-2026',
      title: 'Oktoberfest in Munich',
      date: '2026-09-27T10:00:00+02:00',
      location: 'Munich, Germany',
      description:
        'Join us for an unforgettable day of Bavarian tradition, great company, and celebration at the world\'s most famous folk festival. First 20 signups get a spot!',
      featured: true
    },
    {
      id: 'q1-2027',
      title: 'Q1 2027 &mdash; Ski Retreat',
      date: '2027-02-15T08:00:00+01:00',
      location: 'Alps, Austria',
      description:
        'A weekend of skiing, snowboarding, and team activities in the heart of the Austrian Alps.',
      featured: false
    },
    {
      id: 'q2-2027',
      title: 'Q2 2027 &mdash; Beach Hackathon',
      date: '2027-05-20T09:00:00+02:00',
      location: 'Barcelona, Spain',
      description:
        'Code by day, beach by evening &mdash; a hackathon with a seaside view.',
      featured: false
    }
  ];

  var featured = EVENTS.filter(function (e) { return e.featured; })[0] || EVENTS[0];

  function fillFeatured(event) {
    setText('event-title', event.title);
    setText('event-date', formatDate(event.date));
    setText('event-location', event.location);
    setText('event-description', event.description);
  }

  function renderEvents(events) {
    var list = document.getElementById('events-list');
    if (!list) return;
    list.innerHTML = '';
    events.forEach(function (event) {
      var card = document.createElement('div');
      card.className = 'event-card';
      if (event.featured) card.classList.add('event-card--featured');
      card.innerHTML =
        '<div class="event-card__header">' +
          '<h3 class="event-card__title">' + event.title + '</h3>' +
          (event.featured ? '<span class="event-card__badge">Featured</span>' : '') +
        '</div>' +
        '<div class="event-card__meta">' +
          '<span>' + formatDate(event.date) + '</span>' +
          '<span>' + event.location + '</span>' +
        '</div>' +
        '<p class="event-card__desc">' + event.description + '</p>';
      list.appendChild(card);
    });
  }

  function populateEventSelect(events) {
    var select = document.getElementById('event-select');
    if (!select) return;
    select.innerHTML = '';
    events.forEach(function (event) {
      var opt = document.createElement('option');
      opt.value = event.id;
      opt.textContent = event.title.replace(/<[^>]*>/g, '');
      select.appendChild(opt);
    });
  }

  var form = document.getElementById('signup-form');
  var toast = document.getElementById('toast');
  var toastMessage = document.getElementById('toast-message');
  var toastTimer;

  function showToast(message) {
    clearTimeout(toastTimer);
    toastMessage.textContent = message;
    toast.classList.add('show');
    toastTimer = setTimeout(function () {
      toast.classList.remove('show');
    }, 4000);
  }

  if (form) {
    form.addEventListener('submit', function (e) {
      e.preventDefault();

      var name = document.getElementById('name').value.trim();
      var email = document.getElementById('email').value.trim();
      var eventId = document.getElementById('event-select').value;

      if (!name || !email) {
        showToast('Please fill in all required fields.');
        return;
      }

      if (!email.includes('@') || !email.includes('.')) {
        showToast('Please enter a valid email address.');
        return;
      }

      var selectedEvent = EVENTS.filter(function (e) { return e.id === eventId; })[0];
      var eventName = selectedEvent ? selectedEvent.title.replace(/<[^>]*>/g, '') : 'the event';

      showToast('Thank you, ' + name + '! You are signed up for ' + eventName + '.');
      form.reset();
    });
  }

  var EVENT_DATE = new Date(featured.date);

  function updateCountdown() {
    var now = new Date();
    var diff = Math.max(0, EVENT_DATE - now);

    var days = Math.floor(diff / (1000 * 60 * 60 * 24));
    var hours = Math.floor((diff / (1000 * 60 * 60)) % 24);
    var minutes = Math.floor((diff / (1000 * 60)) % 60);
    var seconds = Math.floor((diff / 1000) % 60);

    var pad = function (n) { return n.toString().padStart(2, '0'); };

    setText('days', pad(days));
    setText('hours', pad(hours));
    setText('minutes', pad(minutes));
    setText('seconds', pad(seconds));
  }

  function setText(id, html) {
    var el = document.getElementById(id);
    if (el) el.innerHTML = html;
  }

  function formatDate(dateStr) {
    var d = new Date(dateStr);
    return d.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    });
  }

  fillFeatured(featured);
  renderEvents(EVENTS);
  populateEventSelect(EVENTS);
  updateCountdown();
  setInterval(updateCountdown, 1000);
})();