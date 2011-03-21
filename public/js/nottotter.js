if (!window.nottotter) window.nottotter = {  };

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
    error: function(res) {
        if (res.status == 0) return;
        alert(res.responseText);
    },
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
	$.ajax({
		url: '/get_timeline',
		    type: 'GET',
		    success: function(data, type, res){
		    self.received(res);
		},
		    error: function(res) {
		    self.error(res);
		},
		    complete: function(res) {
		    self.hideIndicator();
		}
	    })
	self.showIndicator();
    },
    post: function() {
        var self = this;
        console.log('post');
        $.ajax({
            url: '/timeline',
            data: $('#post-tweet').serialize(),
            type: 'POST',
            success: function(res) {
                self.received(res);
            },
            error: function(res) {
                self.error(res);
            },
            complete: function(res) {
                self.hideIndicator();
                self.unlockPostForm();
            }
        });
        self.showIndicator();
        self.lockPostForm();
    },
    received: function(res) {
	if(res.status != 200){
	    location.href = '/timeout';
	    return;
	}
	var currents = $('.tweet');
	var updates = $(res.responseText).find('.tweet');
	var diff = [];
	$.each(updates, function(index, value){
		var nid = value.getAttribute('data-value');
		var flag = true;
		$.each(currents, function(index2, tweet){
			var oid = tweet.getAttribute('data-value');
			if(nid === oid){
			    flag = false;
			    return;
			}
		    });
		if(flag){
		    diff.push(value);
		}
	    });
	$('#timeline').prepend($(diff));
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
    indicatorCount: 0,
    showIndicator: function() {
	this.indicatorCount++;
        $('.indicator').show();
    },
    hideIndicator: function() {
	if(this.indicatorCount > 0){
	    this.indicatorCount--;
	}
	if(this.indicatorCount == 0){
	    $('.indicator').hide();
	}
    },
    reply: function(id, name) {
        console.log(id, name);
        $('#post-tweet-reply-id').val(id);
        $('#post-tweet-textarea').text('@' + name + ' ').focus();
    },
    deleteTweet:  function(id) {
        var self = this;
        var tweet = $('.tweet[data-value=' + id + ']');
        if (!tweeet) return;

        self.showIndicator();
        $.ajax({
            url: '/delete',
            data: {
                id: id,
                token: window.nottotter.user.token,
            },
            type: 'POST',
            success: function(res) {
                tweet.remove();
            },
            error: function(res) {
                self.error(res);
            },
            complete: function(res) {
		self.hideIndicator();
	    }
        });
    }
};


window.nottotter.dispatcher('/timeline', function() {
    window.nottotter.timeline.init();
});

window.nottotter.timeout = {
    'timeout': function() {
	$.post('/timeout', {}, function(res){
		//console.log(res);
	    });
    }
};

window.nottotter.dispatcher('/timeout', function() {
	window.nottotter.timeout.timeout();
});

$(function() {
    window.nottotter.dispatcher();
});
