YAHOO.util.Event.addListener(window, 'load', function () {  
  
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
      {key:"unfetched_reason", label:"Unfetched reason", sortable:true}
  ];
  
  opts = {
    dataSource_fields: ds_fields,
    colDefs: colDefs,
    dataTable_container: 'dt-container'
  }
  var dataTable = commonDT.init(uri, opts)
})