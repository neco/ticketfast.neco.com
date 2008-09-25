
YAHOO.util.Event.addListener(window, 'load', function () {  
  
  // Create the DataSource 
  var uri = "/tickets/list?"; 
  var ds_fields = [
        "id",
        "event_id",
        "event.venue_id",
        "event.name",
        "event.venue.name",
        {key:"event.occurs_at", parser: commonDT.parseDate},
        "section",
        "row",
        "seat"
      ];
  
  
  var myGetQueryConditions = function() {
    var q_str = '';
    for(var i in query_by_fields) {
      if(search_conditions[query_by_fields[i]])
        q_str += '&conditions[' + query_by_fields[i] + ']=' + search_conditions[query_by_fields[i]];
    }
    
    if($('event_name') && $F('event_name') != '')  
      q_str += '&event_name=' + escape($F('event_name'));
    if($('show_all').checked) 
      q_str += '&show_all=1';
    if($('viewed_only').checked) 
      q_str += '&viewed_only=1';
    if($('event-date-select') && $F('event-date-select') != '0') 
      q_str += '&event_id=' + $F('event-date-select');
    if($('customer_name') && $F('customer_name') != '')  
      q_str += '&customer_name=' + escape($F('customer_name'));
    if($('event_code') && $F('event_code') != '')  
      q_str += '&event_code=' + $F('event_code');
      
    return q_str
  }
  
  var search_conditions = {}
  var query_by_fields = ['section', 'order_number', 'row', 'barcode_number', 'seat', 'customer_name', 'event_code'];

  performSearch = function() {
    for(var i in query_by_fields) {
      search_conditions[query_by_fields[i]] = $('query-' + query_by_fields[i]) ? $F('query-' + query_by_fields[i]) : null;
    }
    commonDT.reloadPS()
  }

	var formatters = {
    togglecheckall: function(elCell, oRecord, oColumn, oData) { 
      elCell.innerHTML = '<input type="checkbox" name="tickets[]" value="' + oRecord.getData('id') + '" />'
    },
    viewmore: function(elCell, oRecord, oColumn, oData) { 
      elCell.innerHTML = '<a href="javascript:;" onclick="getTicketDetails(' + oRecord.getData('id') + ')">Details</a>';
    },
    viewpdf: function(elCell, oRecord, oColumn, oData) { 
      elCell.innerHTML = '<a href="/tickets/preview_pdf/' + oRecord.getData('id') + '">PDF</a>';
    },
    quickview: function(elCell, oRecord, oColumn, oData) { 
      elCell.innerHTML = '<a href="/tickets/quickview_ticket/' + oRecord.getData('id') + '" rel="lightbox">Quickview</a>';
    },
    eventDate: function(elCell, oRecord, oColumn, oData) { 
      if(!oData) { elCell.innerHTML = ''; return }
      elCell.innerHTML = (oData.getMonth()+1) + '/' + oData.getDate() + '/' + oData.getFullYear() + ' at ' +
        ((oData.getHours() - 1) % 12 + 1) + ':' + (oData.getMinutes() < 10 ? '0' :'') +oData.getMinutes() + 
        ' ' + (oData.getHours() > 11 ? 'pm' : 'am');
    }
    
  }
  
  // Column definitions 
  var colDefs = [ 
      {key:"id", label:"ID", sortable:true}, 
      {key:"event.name", label:"Event", sortable:true}, 
      {key:"event.venue.name", label:"Venue", sortable:true}, 
      {key:"event.occurs_at", label:"Event Date", sortable:true, formatter:formatters.eventDate},
      {key:"section", label:"Section", sortable:true}, 
      {key:"row", label:"Row", sortable:true}, 
      {key:"seat", label:"Seat", sortable:true}, 
      {key:"togglecheckall", label:'<input type="checkbox" onchange="toggleChecked($(\'tickets_form\'), this)" />', formatter:formatters.togglecheckall},
      {key:"viewmore", label:"Details", formatter:formatters.viewmore},
      {key:"viewpdf", label:"PDF", formatter:formatters.viewpdf},
      {key:"quickview", label:"Quickview", formatter:formatters.quickview}
      
  ]; 
  
  var opts = {
    dataSource_fields: ds_fields,
    colDefs: colDefs,
    dataTable_container: 'dt-container',
    getQueryConditions: myGetQueryConditions
  }
  var dataTable = commonDT.init(uri, opts)
})