var DT = YAHOO.widget.DataTable,
    DS = YAHOO.util.DataSource;
    
YAHOO.util.Event.addListener(window, 'load', function () {
  parseDate = function(data) {
    var dt = data.split("T");
    var tmp = dt[1].split("Z")
    var timeStr = tmp[0].split(":")
    var dateStr = dt[0].split("-")
    
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
        //{key:"ticket.event.occurs_at", parser:parseDate},
        "event.occurs_at",
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
  

  
  
  // Function to generate a query string for a data request
  var ps_generateQueryString = function (start,key,dir,results) { 
    start = start || 0;
    key   = key || 'ticket.id';
    dir   = dir || 'asc';
    results = results || 5;
    return "results="+results+"&startIndex="+start+"&sort="+key+"&dir="+dir;
  };
  
  reloadPS = function() {
    ps_updateDataTable(ps_generateQueryString(), {})
  }
  
  lastStateString = null
  lastArgs = null
  // Expects output from ps_generateQueryString, sends request, updates DataTable
  var ps_updateDataTable = function (stateString, args) { 
    lastStateString = stateString
    lastArgs = args
        
    //stateString += '&ignore_event=' + YAHOO.util.Dom.get('event_ignore').value
    //stateString += '&ignore_section=' + YAHOO.util.Dom.get('section_ignore').value
    //stateString += '&ignore_row=' + YAHOO.util.Dom.get('row_ignore').value
    
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
    checkit: function(elCell, oRecord, oColumn, oData) { 
      elCell.innerHTML = '<input type="checkbox" name="tickets[]" value="' + oRecord.getData('id') + '" />'
    },
    viewmore: function(elCell, oRecord, oColumn, oData) { 
      elCell.innerHTML = 'More'
    }
  }
  
  // Column definitions 
  var ps_colDefs = [ 
      {key:"id", label:"ID", sortable:true}, 
      {key:"event.name", label:"Event", sortable:true}, 
      {key:"event.venue.name", label:"Venue", sortable:true}, 
      {key:"event.occurs_at", label:"Event Date", sortable:true},// formatter:DT.formatDate},
      {key:"section", label:"Section", sortable:true}, 
      {key:"row", label:"Row", sortable:true}, 
      {key:"seat", label:"Seat", sortable:true}, 
      {key:"checkit", label:"", formatter:formatters.checkit},
      {key:"viewmore", label:"", formatter:formatters.viewmore}
      
  ]; 

  // Set up the paginator
  var ps_paginator = new YAHOO.widget.Paginator({ 
      containers         : ['ps_dt-paging'], 
      pageLinks          : 5,
      rowsPerPage        : 5,
      rowsPerPageOptions : [5, 10, 15, 30, 60], 
      pageReportTemplate : "Showing items {startRecord} - {endRecord} of {totalRecords}",
      template           : "<strong>{CurrentPageReport}</strong> {PreviousPageLink} {PageLinks} {NextPageLink} {RowsPerPageDropdown}" 
  }); 

  // Define DataTable config
  var ps_dtConf = { 
      paginator : ps_paginator, 
      paginationEventHandler :  ps_handlePagination,
      selectionMode:"single", // disables modifier keys
      initialRequest : ps_generateQueryString(0, 'ticket.id', "asc", 5),
      caption: "Ticketfast Tickets"
  }; 

  // Instantiate DataTable 
  ps_dataTable = new DT( 
      "ps_dt-container", 
      ps_colDefs,      
      ps_dataSource,        
      ps_dtConf            
  ); 

  // Set up editing 
  highlightEditableCell = function(oArgs) { 
    var elCell = oArgs.target; 
    if(YAHOO.util.Dom.hasClass(elCell, "yui-dt-editable")) { 
      this.highlightCell(elCell); 
    }
  }; 
  ps_dataTable.subscribe("cellMouseoverEvent", highlightEditableCell); 
  ps_dataTable.subscribe("cellMouseoutEvent", ps_dataTable.onEventUnhighlightCell); 
  ps_dataTable.subscribe("cellClickEvent", ps_dataTable.onEventShowCellEditor); 

  ps_dataTable.subscribe("editorBlurEvent", function(oArgs) { 
    this.cancelCellEditor(); 
  });
  // done with editing

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
  
  // Subscribe to events for row selection 
  ps_dataTable.subscribe("rowMouseoverEvent", ps_dataTable.onEventHighlightRow); 
  ps_dataTable.subscribe("rowMouseoutEvent", ps_dataTable.onEventUnhighlightRow); 
  ps_dataTable.subscribe("rowClickEvent", ps_dataTable.onEventSelectRow);
  //ps_dataTable.subscribe("rowSelectEvent", drillDownPriceSuggestion);
})