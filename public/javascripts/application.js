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

var updateEventDates = function() {
  new Ajax.Request("/tickets/get_event_dates", {
    method: 'post',
    parameters: {event_name:$F('event_name'), event_id:$F('event-date-select')},
    onSuccess: function(transport) {
      eval(transport.responseText)
    }
  });

}