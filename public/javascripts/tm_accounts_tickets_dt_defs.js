YAHOO.util.Event.addListener(window, 'load', function () {  
  
  var myGetQueryConditions = function() {
    var q_str = '';
    
    if($('ticket_tm_event_name') && $F('ticket_tm_event_name') != '')  
      q_str += '&tm_event_name=' + escape($F('ticket_tm_event_name'));
    if($('event-date-select') && $F('event-date-select') != '')  
      q_str += '&event_date=' + escape($F('event-date-select'));
    if($('order_number') && $F('order_number') != '')  
      q_str += '&order_number=' + escape($F('order_number'));
    if($('order_date') && $F('order_date') != '')  
      q_str += '&order_date=' + escape($F('order_date'));   
    if($('tm_account_username') && $F('tm_account_username') != '')  
      q_str += '&username=' + escape($F('tm_account_username'));
    if($('ticket_tm_venue_name') && $F('ticket_tm_venue_name') != '')  
      q_str += '&tm_venue_name=' + escape($F('ticket_tm_venue_name'));
      
    return q_str
  }
  


  performSearch = function() {
    commonDT.reloadPS()
  }
  
  
  updateTMEventDates = function() {
    new Ajax.Request("/tm_accounts/get_event_dates?", {
      method: 'post',
      parameters: {tm_event_name:$F('ticket_tm_event_name'), event_id:$F('event-date-select')},
      onSuccess: function(transport) {
        eval(transport.responseText)
      }
    });
  }
  
  
  
  
  
  
  
  
  
  var uri = "/tm_accounts/dt_unfetched?"
  var ds_fields = [
    "id",
    "order_number",
    {key:"tm_order_date", parser: commonDT.parseDate},
    "tm_event_name",
    "tm_venue_name",
    {key:"tm_event_date", parser: commonDT.parseDate},
    "unfetched_reason",
    "tm_account.username"
  ]  
  
  var formatters = {
    dateWithTime: function(elCell, oRecord, oColumn, oData) { 
      if(!oData) { elCell.innerHTML = ''; return }
      elCell.innerHTML = (oData.getMonth()+1) + '/' + oData.getDate() + '/' + oData.getFullYear() + ' at ' +
        ((oData.getHours() - 1) % 12 + 1) + ':' + (oData.getMinutes() < 10 ? '0' :'') + oData.getMinutes() +
        ' ' + (oData.getHours() > 11 ? 'pm' : 'am');
    },
    archive: function(elCell, oRecord, oColumn, oData) { 
      elCell.innerHTML = '<a href="/tm_accounts/archive_unfetched/' + oRecord.getData('id') + '">Archive</a>';
    }
    
  }


  var colDefs = [ 
      {key:"id", label:"ID", sortable:true}, 
      {key:"tm_account.username", label:"Username", sortable:true}, 
      {key:"order_number", label:"Order number", sortable:true},
      {key:"tm_order_date", label:"Order date", sortable:true, formatter:DT.formatDate}, 
      {key:"tm_event_name", label:"Event name", sortable:true},
      {key:"tm_venue_name", label:"Venue name", sortable:true},
      {key:"tm_event_date", label:"Event date", sortable:true, formatter:DT.formatDate},
      {key:"unfetched_reason", label:"Unfetched reason", sortable:true},
      {key:"archive", label:"Archive", formatter:formatters.archive}
  ];
  
  opts = {
    dataSource_fields: ds_fields,
    colDefs: colDefs,
    dataTable_container: 'dt-container',
    getQueryConditions: myGetQueryConditions
  }
  var dataTable = commonDT.init(uri, opts)
})