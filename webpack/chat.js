import MessageBus from 'message-bus-client';

// https://werxltd.com/wp/2010/05/13/javascript-implementation-of-javas-string-hashcode-method/
String.prototype.hashCode = function() {
  let hash = 0, i, chr;
  if (this.length === 0) return hash;
  for (i = 0; i < this.length; i++) {
    chr   = this.charCodeAt(i);
    hash  = ((hash << 5) - hash) + chr;
    hash |= 0; // Convert to 32bit integer
  }
  return hash;
};

const colors = [
  "rosybrown",
  "tomato",
  "black",
  "orange",
  "cornflowerblue",
  "cadetblue",
  "goldenrod",
  "darkred",
  "crimson",
  "chocolate",
  "darkblue",
  "darkgoldenrod",
  "darkcyan",
  "orchid",
  "darkslategrey",
  "darkgreen",
  "darkorange",
  "blue",
  "blueviolet",
  "brown"
];

String.prototype.color = function() {
  return colors[Math.abs(this.hashCode()) % 20];
};

const users = [];

const badge = user => {
  return $('<span/>')
    .text(user)
    .addClass('user badge badge-dark')
    .addClass(user.color());
};

const addUser = user => {
  if (!users.includes(user)) {
    users.push(user);

    $("<span>")
      .append(badge(user))
      .append('<br/>')
      .appendTo('#users');
  }
};

const addMessage = message => {
  var html = $('<div/>')
    .addClass('message')
    .append(badge(message.user));

  html.append(': ')
    .append(message.text)
    .appendTo('#messages');
  
  // auto-scroll
  $('#messages').stop().animate({ 
    scrollTop: $('#messages').prop('scrollHeight')
  }, 1000);
};

$(document).ready(() => {
  $.post(location.pathname + '/enter');

  $('#message').keypress(function(e) {
    if(this.value.length > 0 && e.which == 13) {
      $.post(location.pathname, { text: this.value });      
      this.value = "";
    }
  });

  MessageBus.subscribe(location.pathname, addMessage, 0);
  MessageBus.subscribe(location.pathname + '/enter', addUser, 0);
});
