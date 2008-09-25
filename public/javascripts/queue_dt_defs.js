
YAHOO.util.Event.addListener(window, 'load', function () {  
  
  // Create the DataSource 
  var uri = "/tickets/list?show_all=true&"; 
  var ds_fields = [
        "id",
        {key:"email_sent_at", parser: commonDT.parseDate},
        "email_from",
        "email_subject"
      ];
  
  var myGetQueryConditions = function() {
    return '&unparsed=1';
  }
  	
	var formatters = {
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
      {key:"email_sent_at", label:"Email Sent On", sortable:true, formatter:formatters.eventDate},
      {key:"email_from", label:"Email Sender", sortable:true}, 
      {key:"email_subject", label:"Email Subject", sortable:true}, 
      {key:"viewmore", label:"Edit", formatter:formatters.openform},
      {key:"viewpdf", label:"PDF", formatter:formatters.viewpdf},
      {key:"quickview", label:"Quickview", formatter:formatters.quickview}//,
  //    {key:"viewtext", label:"PDF Text", formatter:formatters.viewtext},
   //   {key:"tryparse", label:"Parse", formatter:formatters.tryparse}
      
  ]; 
  
  var opts = {
    dataSource_fields: ds_fields,
    colDefs: colDefs,
    dataTable_container: 'dt-container',
    getQueryConditions: myGetQueryConditions
  }
  var dataTable = commonDT.init(uri, opts)
    
  // Set up editing 
  var highlightEditableCell = function(oArgs) { 
    var elCell = oArgs.target.firstChild; 
    
    if(YAHOO.util.Dom.hasClass(elCell, "yui-dt-editable")) { 
      
      this.highlightCell(elCell); 
    }
  }; 
  dataTable.subscribe("cellMouseoverEvent", highlightEditableCell); 
  dataTable.subscribe("cellMouseoutEvent", commonDT.dataTable.onEventUnhighlightCell); 
  dataTable.subscribe("cellClickEvent", commonDT.dataTable.onEventShowCellEditor); 

  dataTable.subscribe("editorBlurEvent", function(oArgs) { 
    this.cancelCellEditor(); 
  });
  // done with editing
})