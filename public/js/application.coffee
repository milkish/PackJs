
$("button.version").live "click", ->
  $(this).siblings().removeClass("active")
  setTimeout refresh_pack, 50

$("tr.lib_row").live "click", (e)->
  unless $(e.target).hasClass("version")
    $(this).find("button.newest").click()
  #alert e.currentTarget == this
  # $(this).find("button.newest").click()

master_sort = [
  "jquery"
  "less"
  "prototype"
  "underscore"
  "zepto"
  "jqueryui"
  "jquery_mobile"
  "backbone"
  "knockout"
]


pack = []

compact = (arr)->
  copy = []
  copy.push(item) for item in arr when item isnt undefined
  copy

refresh_pack = ->
  pack = []
  content = ""
  $("button.version.active").each ->
    lib_id     = $(this).parent().data "lib_id"
    version_id = $(this).text().trim()
    sort_id    = master_sort.indexOf lib_id 
    pack[sort_id] = lib_id
    if version_id != "Newest"
      pack[sort_id] += "-" + version_id
  
  pack = compact pack

  pack_url = "http://packjs.com/"+pack.join("+")

  $("#pack_contents").html content
  $("#pack_url").html pack_url

  if pack.length then show_pack_box() else hide_pack_box()


show_pack_box = ->
  $("#pack_url_box").animate({"top":40})
  $("#wrapper").animate({"margin-top": 90})

hide_pack_box = ->
  $("#pack_url_box").animate({"top":0})
  $("#wrapper").animate({"margin-top": 50})