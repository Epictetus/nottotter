window.nottotter = {  };

window.nottotter.dispatcher = function(guard, func) {
    window.nottotter.dispatcher.path_func = window.nottotter.dispatcher.path_func || []
    if (func) {
        window.nottotter.dispatcher.path_func.push([guard, func]);
        return;
    }
    window.nottotter.dispatcher.path_func.forEach(function(pair) {
        var guard = pair[0];
        var func = pair[1];

        if (
            guard == true
                || (typeof guard == "string" && location.pathname == guard)
                || (guard.test && guard.test(location.pathname))
        ) func();
    });
};

window.nottotter.timeline = {
    init: function() {
        var self = this;
        console.log('init timeline');
        setInterval(function() {
            self.getTimeline();
        }, 10000);

        self.bindEvents();
    },
    bindEvents: function() {
        var self = this;
        $('form#post-tweet').submit(function(event) {
            self.post();
            return false;
        });
        $('.tweet-footer-item.reply').live('click', function() {
            var status_id = $(this).attr("data-status-id");
            var screen_name = $(this).attr("data-screen-name");
            self.reply(status_id, screen_name);
            return false;
        });

        $('.tweet-footer-item.delete').live('click', function() {
            var status_id = $(this).attr("data-status-id");
            if (confirm('削除しますか？')) {
                self.deleteTweet(status_id);
            }
            return false;
        });
    },
    getTimeline: function() {
        var self = this;
        console.log('getTimeline');
        $.getJSON('/timeline.json', self.received);
    },
    post: function() {
        var self = this;
        console.log('post');
        $.post('/timeline', $('#post-tweet').serialize(), function(res) {
            self.hideIndicator();
            self.unlockPostForm();
            self.received(res);
        });
        self.showIndicator();
        self.lockPostForm();
    },
    received: function(data) {
        console.log('got');
        console.log(data);
    },
    lockPostForm: function() {
        $('#post-tweet input, #post-tweet textarea').each(function() { $(this).attr('disabled', true) });
    },
    unlockPostForm: function() {
        $('#post-tweet input, #post-tweet textarea').each(function() {
            $(this).attr('disabled', false);
            if ($(this).attr('type') != 'submit') $('#post-tweet textarea').val('');
        });
    },
    showIndicator: function() {
        $('.indicator').show();
    },
    hideIndicator: function() {
        $('.indicator').hide();
    },
    reply: function(id, name) {
        console.log(id, name);
        $('#post-tweet-reply-id').val(id);
        $('#post-tweet-textarea').text('@' + name + ' ').focus();
    },
    deleteTweet:  function(id) {
        var tweet = $('.tweet[data-value=' + id + ']');

        $.post(
	    '/delete', 
	    { "id": id , "location": location.pathname },
	    function(res) {
	        tweet.remove();
	        return false;
	    });
    }
};


window.nottotter.dispatcher('/timeline', function() {
    window.nottotter.timeline.init();
});

$(function() {
    window.nottotter.dispatcher();
});
