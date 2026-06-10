(function () {
  var EVENT_DATE = new Date('2026-09-27T10:00:00+02:00');

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
      var company = document.getElementById('company').value.trim();
      var guests = document.getElementById('guests').value;

      if (!name || !email || !company) {
        showToast('Please fill in all required fields.');
        return;
      }

      if (!email.includes('@') || !email.includes('.')) {
        showToast('Please enter a valid email address.');
        return;
      }

      showToast('Thank you, ' + name + '! Your registration has been received.');

      form.reset();
    });
  }

  function updateCountdown() {
    var now = new Date();
    var diff = Math.max(0, EVENT_DATE - now);

    var days = Math.floor(diff / (1000 * 60 * 60 * 24));
    var hours = Math.floor((diff / (1000 * 60 * 60)) % 24);
    var minutes = Math.floor((diff / (1000 * 60)) % 60);
    var seconds = Math.floor((diff / 1000) % 60);

    var pad = function (n) { return n.toString().padStart(2, '0'); };

    var el = function (id) { return document.getElementById(id); };

    el('days').textContent = pad(days);
    el('hours').textContent = pad(hours);
    el('minutes').textContent = pad(minutes);
    el('seconds').textContent = pad(seconds);
  }

  updateCountdown();
  setInterval(updateCountdown, 1000);
})();