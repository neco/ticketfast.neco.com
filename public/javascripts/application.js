var toggleEmailForm = function() {
  if($('email_sel_form_div').style.display == '') {
    $('email_sel_form_div').style.display = 'none'
    $('recipient_sel').value = ''
    $('submit_tag').value = 'Download Selected'
  } else {
    $('email_sel_form_div').style.display = ''
    $('submit_tag').value = 'E-mail Selected'
  }
}
var checkAll = function(frm) {
  for (i in frm.elements) {
    if(frm.elements[i].type == 'checkbox')
      frm.elements[i].checked=true;
  }
}
var uncheckAll = function(frm) {
  for (i in frm.elements) {
    if(frm.elements[i].type == 'checkbox')
      frm.elements[i].checked=false;
  }
}
var toggleChecked = function(frm,objid) {
  obj=$(objid);
  if(obj.checked==true) checkAll(frm);
  else uncheckAll(frm);
}

var getTicketDetails = function(ticket_id) {
  new Ajax.Updater('ticket-details', "/tickets/get_details/" + ticket_id)
}

var getTicketQueueForm = function(ticket_id) {
  if($('queue-form')) $('queue-form').remove()
  new Ajax.Updater('ticket-form', "/tickets/edit/" + ticket_id, {
    onSuccess: function(t){
      prepareForm()
    }
  })
}

var updateEventDates = function(custom, event_id) {
  new Ajax.Request(("/tickets/get_event_dates?" + (custom ? 'custom_opt=1&' : '') + (event_id ? 'event_id=' + event_id : '')), {
    method: 'post',
    parameters: {event_name:$F('event_name'), event_id:$F('event-date-select'), show_all:$F('show_all'), viewed_only:$F('viewed_only')},
    onSuccess: function(transport) {
      eval(transport.responseText)
    }
  });

}