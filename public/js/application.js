(function() {
  var compact, hide_pack_box, master_sort, pack, refresh_pack, show_pack_box;

  $("button.version").live("click", function() {
    $(this).siblings().removeClass("active");
    return setTimeout(refresh_pack, 50);
  });

  $("tr.lib_row").live("click", function(e) {
    if (!$(e.target).hasClass("version")) {
      return $(this).find("button.newest").click();
    }
  });

  master_sort = ["jquery", "less", "prototype", "underscore", "zepto", "jqueryui", "jquery_mobile", "backbone", "knockout"];

  pack = [];

  compact = function(arr) {
    var copy, item, _i, _len;
    copy = [];
    for (_i = 0, _len = arr.length; _i < _len; _i++) {
      item = arr[_i];
      if (item !== void 0) copy.push(item);
    }
    return copy;
  };

  refresh_pack = function() {
    var content, pack_url;
    pack = [];
    content = "";
    $("button.version.active").each(function() {
      var lib_id, sort_id, version_id;
      lib_id = $(this).parent().data("lib_id");
      version_id = $(this).text().trim();
      sort_id = master_sort.indexOf(lib_id);
      pack[sort_id] = lib_id;
      if (version_id !== "Newest") return pack[sort_id] += "-" + version_id;
    });
    pack = compact(pack);
    pack_url = "http://packjs.com/" + pack.join("+");
    $("#pack_contents").html(content);
    $("#pack_url").html(pack_url);
    if (pack.length) {
      return show_pack_box();
    } else {
      return hide_pack_box();
    }
  };

  show_pack_box = function() {
    $("#pack_url_box").animate({
      "top": 40
    });
    return $("#wrapper").animate({
      "margin-top": 90
    });
  };

  hide_pack_box = function() {
    $("#pack_url_box").animate({
      "top": 0
    });
    return $("#wrapper").animate({
      "margin-top": 50
    });
  };

}).call(this);
