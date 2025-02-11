/**
* Description of task
*/
component {

	/**
	*
	*/
	function run() {
		variables.PAT = getSystemSetting( 'report_github_pat' );

		repos = getRepos( 'coldbox-modules' )
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
			if( runs[i].status == 'completed' && runs[i].event != 'pull_request' && !(runs[i].name contains 'Pull Request') ) {
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

	function getRepos( orgName ) {
		var theURL = 'https://api.github.com/orgs/#orgName#/repos';
		http url=theURL result="local.result" {
			httpparam type="header" name="Authorization" value="token #PAT#";
		}
		//print.line( local.result.responseHeader['X-RateLimit-Remaining'] & ' API hits remaining this hour' ).line().line().toConsole();
		return deserializeJSON(local.result.fileContent)
			.map(  (repo) => {
				return repo.full_name;
			});		
	}

}
