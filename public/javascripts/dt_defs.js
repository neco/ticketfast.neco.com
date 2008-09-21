var DT = YAHOO.widget.DataTable;
var DS = YAHOO.util.DataSource;

var commonDT = {
  dataTable: null,
  getQueryConditions: function(){alert('foo')},
  
  parseDate: function(data) {
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
  },
  
  // Expects output from generateQueryString, sends request, updates DataTable
  updateDataTable: function (stateString, args) { 
    this.dataTable.getRecordSet().reset()
    
    this.dataSource.sendRequest(stateString,{ 
      success  : this.dataTable.onDataReturnSetRows, 
      failure  : this.dataTable.onDataReturnSetRows, 
      argument : args,
      scope    : this.dataTable
    });
  },
  

  
  // Function to generate a query string for a data request
  generateQueryString: function (start,key,dir,results) { 
    start = start || 0;
    dir   = dir || 'asc';
    results = results || 15;
    var qstr = "results="+results+"&startIndex="+start;
    if(key && key != 'none') qstr += "&sort="+key;
    qstr += "&dir="+dir+this.getQueryConditions();
    return qstr
  },
  
  // Function used to intercept sorting requests 
  // event handler! this.? does not work
	handleSorting: function (oColumn) { 
    // Which direction 
    var sDir = "asc"; 
 
    // Already sorted? 
    if(oColumn.key === this.get("sortedBy").key) { 
      sDir = (this.get("sortedBy").dir === "asc") ? 
        "desc" : "asc"; 
    } 
    
    var newState = commonDT.generateQueryString(0, oColumn.key, sDir); 
	  

    commonDT.updateDataTable(newState)
	},
	
	// Function used to intercept pagination requests 
	handlePagination: function (state,datatable) { 
    var sortedBy  = datatable.get('sortedBy'); 
    var newState = commonDT.generateQueryString( 
      state.recordOffset, 
      sortedBy.key, 
      sortedBy.dir,
      state.rowsPerPage);
    
    commonDT.updateDataTable(newState,   {
          startIndex : state.recordOffset,
          pagination : state
      });
	},
  
  // Set up the paginator
  setupPaginator: function() {
    this.paginator = new YAHOO.widget.Paginator({ 
        containers         : ['dt-paging'], 
        pageLinks          : 5,
        rowsPerPage        : 15,
        rowsPerPageOptions : [15, 30, 60, 150], 
        pageReportTemplate : "Showing items {startRecord} - {endRecord} of {totalRecords}",
        template           : "<strong>{CurrentPageReport}</strong> {PreviousPageLink} {PageLinks} {NextPageLink} {RowsPerPageDropdown}" 
    })
  },
  
  init: function(dt_container_id, dataSource, colDefs, gqc) {
    this.dataSource = dataSource;
    this.getQueryConditions = gqc;
    this.setupPaginator();
    
    var dtConf = { 
        paginator : this.paginator, 
        paginationEventHandler :  this.handlePagination,
        selectionMode:"single", // disables modifier keys
        initialRequest : this.generateQueryString(0, null, "asc", 15),
    }; 

    // Instantiate DataTable 
    this.dataTable = new DT( 
        dt_container_id,
        colDefs,
        dataSource,
        dtConf
    );
    
    this.dataTable.sortColumn = this.handleSorting;
    
  }
  
}
