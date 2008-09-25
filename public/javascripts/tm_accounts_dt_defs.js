YAHOO.util.Event.addListener(window, 'load', function () {  
  
  var uri = "/tm_accounts/list?"
  var ds_fields = [
    "id",
    "username",
    "password",
    {key:"worker_last_update_at", parser: commonDT.parseDate},
    "disabled",
    "worker_status",
    "worker_job_target",
    "fetched_count",
    "unfetched_count"
  ]
  
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
  
  var myGetQueryConditions = function() {
    var q_str = '';
    if($('query') && $F('query') != '')  
      q_str += '&query=' + escape($F('query'));
    return q_str
  }
  
  performSearch = function() {
    commonDT.reloadPS()
  }
  
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
  
  opts = {
    dataSource_fields: ds_fields,
    colDefs: colDefs,
    dataTable_container: 'dt-container',
    getQueryConditions: myGetQueryConditions
  }
  var dataTable = commonDT.init(uri, opts)
})