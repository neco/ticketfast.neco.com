
YAHOO.util.Event.addListener(window, 'load', function () {  
    
  // Create the DataSource 
  dataSource = new DS("/tm_accounts/list?"); 
  dataSource.responseType = DS.TYPE_JSON; 
  dataSource.responseSchema = { 
      resultsList: "records", 
      fields: [
        "id",
        "username",
        "password",
        {key:"worker_last_update_at", parser: commonDT.parseDate},
        "disabled",
        "worker_status",
        "worker_job_target",
        "fetched_count",
        "unfetched_count"
      ], 
      metaFields: { 
          totalRecords: "totalRecords", 
          paginationRecordOffset : "startIndex", 
          sortKey: "sort", 
          sortDir: "dir" 
      } 
  };
  
  
  var myGetQueryConditions = function() {
    
    var q_str = '';

    return q_str
  }

  
  reloadPS = function() {
    commonDT.updateDataTable(commonDT.generateQueryString(), {})
  }
  

  


	
	var formatters = {
    fetched: function(elCell, oRecord, oColumn, oData) { 
      elCell.innerHTML = '<a href="/tm_accounts/list_fetched/' +  oRecord.getData('id') + '">'+oRecord.getData('fetched_count')+'</a>';
    },
    unfetched: function(elCell, oRecord, oColumn, oData) { 
      elCell.innerHTML = '<a href="/tm_accounts/list_unfetched/' +  oRecord.getData('id') + '">'+oRecord.getData('unfetched_count')+'</a>';    
    },
    worker_status: function(elCell, oRecord, oColumn, oData) { 
      elCell.innerHTML = (oRecord.getData('disabled') ? 'Disabled' : 'Enabled') + ' - ' + oRecord.getData('worker_status') + ' (<a href="/tm_accounts/toggle_disabled/' + oRecord.getData('id') + '">' + (oRecord.getData('disabled') ? 'enable' : 'disable') + '</a>)';
    },
    force_fetch: function(elCell, oRecord, oColumn, oData) { 
      elCell.innerHTML = '<a href="/tm_accounts/manual_fetch/'+ oRecord.getData('id') +'">Fetch</a>';
    },
    remove: function(elCell, oRecord, oColumn, oData) { 
      elCell.innerHTML = '<a href="/tm_accounts/destroy/'+ oRecord.getData('id') + '" onclick="return confirm(\'Are you sure you want to delete this account?\');">Remove</a>';
    },
    dateWithTime: function(elCell, oRecord, oColumn, oData) { 
      if(!oData) { elCell.innerHTML = ''; return }
      elCell.innerHTML = (oData.getMonth()+1) + '/' + oData.getDate() + '/' + oData.getFullYear() + ' at ' +
        ((oData.getHours() - 1) % 12 + 1) + ':' + (oData.getMinutes() < 10 ? '0' :'') + oData.getMinutes() +
        ' ' + (oData.getHours() > 11 ? 'pm' : 'am');
    }
    
  }
  
  // Column definitions 
  var colDefs = [ 
      {key:"id", label:"ID", sortable:true}, 
      {key:"username", label:"Username", sortable:true}, 
      {key:"password", label:"Password", sortable:true}, 
      {key:"fetched", label:"Fetched", formatter:formatters.fetched},
      {key:"unfetched", label:"Unfetched", formatter:formatters.unfetched},
      {key:"worker_status", label:"Status", formatter:formatters.worker_status},
      {key:"worker_last_update_at", label:"Last checked", sortable:true, formatter:formatters.dateWithTime},
      {key:"force_fetch", label:"Force fetch", formatter:formatters.force_fetch},
      {key:"remove", label:"Remove", formatter:formatters.remove}
      
  ]; 
  
  commonDT.init('dt-container', dataSource, colDefs, myGetQueryConditions);
})