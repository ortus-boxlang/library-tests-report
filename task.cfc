/**
* Description of task
*/
component {

	/**
	*
	*/
	function run() {
		variables.PAT = getSystemSetting( 'REPORT_GITHUB_PAT' );
		variables.coldbox_token=getSystemSetting( 'COLDBOX_TOKEN' );
		variables.ortus_token=getSystemSetting( 'ORTUS_TOKEN' );
		variables.coldbox_modules_token=getSystemSetting( 'COLDBOX_MODULES_TOKEN' );
		variables.ortus_boxlang_token=getSystemSetting( 'ORTUS_BOXLANG_TOKEN' );

		var repos = getRepos( 'coldbox-modules' )
			.append( getRepos( 'ColdBox' ), true )
			.append( getRepos( 'Ortus-Solutions' ), true );

		repos.each( (repo) => {
			var lastRunID = getLastRunID(repo);
			if( lastRunID ) {
				var BLJobs = getJobs(repo, lastRunID);
				if( BLJobs.len() ) {
					lock name="boxlang-job-report" type="exclusive" timeout="10" {	
						print.Boldline( repo ).toConsole();
						print.indentedLine( 'https://github.com/#repo#/actions/runs/#lastRunID#' ).line().toConsole();
						BLJobs.each(  (job) => {
								print.indentedLine( job.workflow_name & ' - ' & job.name & ' - ' & job.conclusion & ' @ ' & dateTimeFormat( job.completed_at ), job.conclusion == 'success' ? 'green' : 'red' ).toConsole();
							});
						print.line().toConsole();
					}
				}
			}
		}, true);

		print.line().line( "Checking for inactive workflows" ).toConsole();
		repos.each( (repo) => {
			getInactiveWorkflows( repo ).each( (workflow) => {
				
				var theURL = 'https://api.github.com/repos/#repo#/actions/workflows/#workflow.id#/enable';
				http url=theURL result="local.result" method="PUT" {
					httpparam type="header" name="Authorization" value="Bearer #getPATForRepo( repo.listFirst('/') )#";
				}
				print.Boldline( "Re-activated #repo# #workflow.name#" ).toConsole();
			});
		}, true);

		print.line().line( "Updating last run in repo" ).toConsole();
		updateLastRun();

	}

	function updateLastRun() {
		
		var theURL = 'https://api.github.com/repos/ortus-boxlang/library-tests-report/contents/lastRun.txt';
		
		// Get existing file SHA
		http url=theURL method="GET" result="local.getResult" {
			httpparam type="header" name="Authorization" value="Bearer #ortus_boxlang_token#";
			httpparam type="header" name="Accept" value="application/vnd.github+json";
		}
		
		var payload = {
			"message": "Update last run",
			"content": toBase64(now().toString()),
			"branch": "development"
		};
		
		// Add SHA if file exists
		if (local.getResult.status_Code == "200") {
			payload['sha'] = deserializeJSON(local.getResult.fileContent).sha;
		} else {
			print.line( getResult ).toConsole();
		}
		
		http url=theURL method="PUT" result="local.result" {
			httpparam type="header" name="Authorization" value="Bearer #ortus_boxlang_token#";
			httpparam type="header" name="Accept" value="application/vnd.github+json";
			httpparam type="body" value="#serializeJSON(payload)#";
		}
	}

	function getPATForRepo( orgName ) {
		switch( orgName ) {
			case 'ColdBox' : return variables.coldbox_token;
			case 'Ortus-Solutions' : return variables.ortus_token;
			case 'coldbox-modules' : return variables.coldbox_modules_token;
			default : return variables.PAT;
		}
	}

	function getInactiveWorkflows( repo ) {
		var theURL = 'https://api.github.com/repos/#repo#/actions/workflows';
		http url=theURL result="local.result" {
			httpparam type="header" name="Authorization" value="Bearer #PAT#";
		}

		return deserializeJSON(local.result.fileContent)
			.workflows
			.filter( (workflow) => workflow.state == 'disabled_inactivity' )
			.map( (workflow) => {
				return {
					'id' : workflow.id,
					'name' : workflow.name,
					'path' : workflow.path
				};
			} );		
	}

	function getLastRunID(repo) {
		var theURL = 'https://api.github.com/repos/#repo#/actions/runs';
		http url=theURL result="local.result" {
			httpparam type="header" name="Authorization" value="Bearer #PAT#";
		}
		var runs = deserializeJSON(local.result.fileContent).workflow_runs;
		var i = 1;
		while( i <= runs.len() ) {
			// Skip any running workflows
			if( runs[i].status == 'completed' && runs[i].event != 'pull_request' && !(runs[i].name contains 'Pull Request') && !(runs[i].name contains 'Release') ) {
				return runs[i].id;
			}
			i++;
		}
		return 0;
	}

	function getJobs(repo, runID) {
		var theURL = 'https://api.github.com/repos/#repo#/actions/runs/#runID#/jobs';
		http url=theURL result="local.result" {
			httpparam type="header" name="Authorization" value="Bearer #PAT#";
		}
		var data = deserializeJSON(local.result.fileContent)
			.jobs
			.filter( (job) => job.name contains 'boxlang' )
			.map( (job) => {
				return {
					'workflow_name' : job.workflow_name,
					'name' : job.name,
					'conclusion' : job.conclusion,
					'completed_at' : job.completed_at
				};
			});

		return data;
	}

	function getRepos( orgName, page=1 ) {
		var repos = [];
		var theURL = 'https://api.github.com/orgs/#orgName#/repos?page=#page#&per_page=100';
		http url=theURL result="local.result" {
			httpparam type="header" name="Authorization" value="token #PAT#";
		}
		
		//print.line( local.result.responseHeader['X-RateLimit-Remaining'] & ' API hits remaining this hour' ).line().line().toConsole();
		repos.append( deserializeJSON(local.result.fileContent)
			.map(  (repo) => {
				return repo.full_name;
			}), true );		

		// check for pagination
		if( structKeyExists( local.result.responseHeader, 'Link' ) ) {
			var links = local.result.responseHeader['Link'].listToArray( ',' );
			links.each( (link) => {
				if( link contains 'rel="next"' ) {
					var nextURL = rereplace( link, '<(.*)>; rel="next"', '\1' );
					var nextPage = listLast( nextURL.listToArray( '?' )[2], '=' );
					repos.append( getRepos( orgName, nextPage ), true );
				}
			});
		}

		return repos;
	}

}
