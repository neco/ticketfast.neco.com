
YAHOO.util.Event.addListener(window, 'load', function () {  
  
  // Create the DataSource 
  dataSource = new DS("/tickets/list?"); 
  dataSource.responseType = DS.TYPE_JSON; 
  dataSource.responseSchema = { 
      resultsList: "records", 
      fields: [
        "id",
        "event_id",
        "event.venue_id",
        "event.name",
        "event.venue.name",
        {key:"event.occurs_at", parser: commonDT.parseDate},
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
  
  
  var myGetQueryConditions = function() {
    return '&unparsed=1';
  }
  
  reloadPS = function() {
    commonDT.updateDataTable(commonDT.generateQueryString(), {})
  }
  

  


	
	var formatters = {
    togglecheckall: function(elCell, oRecord, oColumn, oData) { 
      elCell.innerHTML = '<input type="checkbox" name="tickets[]" value="' + oRecord.getData('id') + '" />'
    },
    openform: function(elCell, oRecord, oColumn, oData) { 
      elCell.innerHTML = '<a href="javascript:;" onclick="getTicketQueueForm(' + oRecord.getData('id') + ')">Edit</a>';
    },
    viewpdf: function(elCell, oRecord, oColumn, oData) { 
      elCell.innerHTML = '<a href="/tickets/preview_pdf/' + oRecord.getData('id') + '">PDF</a>';
    },
    quickview: function(elCell, oRecord, oColumn, oData) { 
      elCell.innerHTML = '<a href="/tickets/quickview_ticket/' + oRecord.getData('id') + '" rel="lightbox">Quickview</a>';
    },
    viewtext: function(elCell, oRecord, oColumn, oData) { 
      elCell.innerHTML = '<a href="/tickets/view_text/' + oRecord.getData('id') + '">PDF Text</a>';
    },
    tryparse: function(elCell, oRecord, oColumn, oData) { 
      elCell.innerHTML = '<a href="/tickets/parse/' + oRecord.getData('id') + '">Parse</a>';
    },
    eventDate: function(elCell, oRecord, oColumn, oData) { 
      if(!oData) { elCell.innerHTML = ''; return }
      elCell.innerHTML = (oData.getMonth()+1) + '/' + oData.getDate() + '/' + oData.getFullYear() + ' at ' +
        ((oData.getHours() - 1) % 12 + 1) + ':' + oData.getMinutes() + (oData.getMinutes() < 10 ? '0' :'') +
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
      {key:"viewmore", label:"Edit", formatter:formatters.openform},
      {key:"viewpdf", label:"PDF", formatter:formatters.viewpdf},
      {key:"quickview", label:"Quickview", formatter:formatters.quickview}//,
  //    {key:"viewtext", label:"PDF Text", formatter:formatters.viewtext},
   //   {key:"tryparse", label:"Parse", formatter:formatters.tryparse}
      
  ]; 
  
  commonDT.init('dt-container', dataSource, colDefs, myGetQueryConditions);
  
  // Set up editing 
  var highlightEditableCell = function(oArgs) { 
    var elCell = oArgs.target.firstChild; 
    
    if(YAHOO.util.Dom.hasClass(elCell, "yui-dt-editable")) { 
      
      this.highlightCell(elCell); 
    }
  }; 
  commonDT.dataTable.subscribe("cellMouseoverEvent", highlightEditableCell); 
  commonDT.dataTable.subscribe("cellMouseoutEvent", commonDT.dataTable.onEventUnhighlightCell); 
  commonDT.dataTable.subscribe("cellClickEvent", commonDT.dataTable.onEventShowCellEditor); 

  commonDT.dataTable.subscribe("editorBlurEvent", function(oArgs) { 
    this.cancelCellEditor(); 
  });
  // done with editing
})