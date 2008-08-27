var DT = YAHOO.widget.DataTable,
    DS = YAHOO.util.DataSource;

YAHOO.util.Event.addListener(window, 'load', function () {  
  parseDate = function(data) {
    if(!data) return null; 
    var tmp = data.split(" ");
    var timeStr = tmp[1].split(":")
    var dateStr = tmp[0].split("/")
    
    var date = new Date()
    date.setYear(dateStr[0])
    date.setMonth(dateStr[1] - 1)
    date.setDate(dateStr[2])
    date.setHours(timeStr[0])
    date.setMinutes(timeStr[1])
    date.setSeconds(timeStr[2])
    return date
  };
  
  // Create the DataSource 
  ps_dataSource = new DS("/tickets/list?"); 
  ps_dataSource.responseType = DS.TYPE_JSON; 
  ps_dataSource.responseSchema = { 
      resultsList: "records", 
      fields: [
        "id",
        "event_id",
        "event.venue_id",
        "event.name",
        "event.venue.name",
        {key:"event.occurs_at", parser:parseDate},
        "section",
        "row",
        "seat"
      ], 
      metaFields: { 
          totalRecords: "totalRecords", 
          paginationRecordOffset : "startIndex", 
          sortKey: "sort", 
          sortDir: "dir" 
      } 
  };
  
  
  var getQueryConditions = function() {
    var q_str = '';
    for(var i in query_by_fields) 
      if(search_conditions[query_by_fields[i]])
        q_str += '&conditions[' + query_by_fields[i] + ']=' + search_conditions[query_by_fields[i]];
    if($('event_name') && $F('event_name') != '')  q_str += '&event_name=' + $F('event_name')
    if($('show_all').checked) q_str += '&show_all=1'
    if($('customer_name') && $F('customer_name') != '')  q_str += '&customer_name=' + $F('customer_name')
    if($('event_code') && $F('event_code') != '')  q_str += '&event_code=' + $F('event_code')
    return q_str
  }
  
  var search_conditions = {}
  var query_by_fields = ['section', 'order_number', 'row', 'barcode_number', 'seat', 'customer_name', 'event_code'];

  performSearch = function() {
    for(var i in query_by_fields) {
      search_conditions[query_by_fields[i]] = $('query-' + query_by_fields[i]) ? $F('query-' + query_by_fields[i]) : null;
    }
    reloadPS()
  }
  
  
  // Function to generate a query string for a data request
  var ps_generateQueryString = function (start,key,dir,results) { 
    start = start || 0;
    key   = key || 'ticket.id';
    dir   = dir || 'asc';
    results = results || 15;
    return "results="+results+"&startIndex="+start+"&sort="+key+"&dir="+dir+getQueryConditions();
  };
  
  reloadPS = function() {
    ps_updateDataTable(ps_generateQueryString(), {})
  }
  
  // Expects output from ps_generateQueryString, sends request, updates DataTable
  var ps_updateDataTable = function (stateString, args) { 
    ps_dataTable.getRecordSet().reset()
    
    ps_dataSource.sendRequest(stateString,{ 
      success  : ps_dataTable.onDataReturnSetRows, 
      failure  : ps_dataTable.onDataReturnSetRows, 
      argument : args,
      scope    : ps_dataTable
    });
  };
  
	// Function used to intercept pagination requests 
	var ps_handlePagination = function (state,datatable) { 
    var sortedBy  = datatable.get('sortedBy'); 
    var newState = ps_generateQueryString( 
      state.recordOffset, 
      sortedBy.key, 
      sortedBy.dir,
      state.rowsPerPage);
    
    ps_updateDataTable(newState,   {
          startIndex : state.recordOffset,
          pagination : state
      });
	};

	
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
        ((oData.getHours() - 1) % 12 + 1) + ':' + oData.getMinutes() + (oData.getMinutes() < 10 ? '0' :'') +
        ' ' + (oData.getHours() > 11 ? 'pm' : 'am');
    }
    
  }
  
  // Column definitions 
  var ps_colDefs = [ 
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

  // Set up the paginator
  var ps_paginator = new YAHOO.widget.Paginator({ 
      containers         : ['ps_dt-paging'], 
      pageLinks          : 5,
      rowsPerPage        : 15,
      rowsPerPageOptions : [15, 30, 60, 150], 
      pageReportTemplate : "Showing items {startRecord} - {endRecord} of {totalRecords}",
      template           : "<strong>{CurrentPageReport}</strong> {PreviousPageLink} {PageLinks} {NextPageLink} {RowsPerPageDropdown}" 
  }); 

  // Define DataTable config
  var ps_dtConf = { 
      paginator : ps_paginator, 
      paginationEventHandler :  ps_handlePagination,
      selectionMode:"single", // disables modifier keys
      initialRequest : ps_generateQueryString(0, 'ticket.created_at', "desc", 15),
  }; 

  // Instantiate DataTable 
  ps_dataTable = new DT( 
      "ps_dt-container", 
      ps_colDefs,      
      ps_dataSource,        
      ps_dtConf            
  ); 


  // Function used to intercept sorting requests 
	var ps_handleSorting = function (oColumn) { 
    // Which direction 
    var sDir = "asc"; 
 
    // Already sorted? 
    if(oColumn.key === this.get("sortedBy").key) { 
      sDir = (this.get("sortedBy").dir === "asc") ? 
        "desc" : "asc"; 
    } 
 
    var newState = ps_generateQueryString(0, oColumn.key, sDir); 

    ps_updateDataTable(newState)
	};
  
  
  // Override the DataTable's sortColumn method with our handler 
  ps_dataTable.sortColumn = ps_handleSorting;
})