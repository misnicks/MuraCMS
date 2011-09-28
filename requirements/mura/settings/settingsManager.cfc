<!--- This file is part of Mura CMS.

Mura CMS is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, Version 2 of the License.

Mura CMS is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. �See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Mura CMS. �If not, see <http://www.gnu.org/licenses/>.

Linking Mura CMS statically or dynamically with other modules constitutes
the preparation of a derivative work based on Mura CMS. Thus, the terms and 	
conditions of the GNU General Public License version 2 (�GPL�) cover the entire combined work.

However, as a special exception, the copyright holders of Mura CMS grant you permission
to combine Mura CMS with programs or libraries that are released under the GNU Lesser General Public License version 2.1.

In addition, as a special exception, �the copyright holders of Mura CMS grant you permission
to combine Mura CMS �with independent software modules that communicate with Mura CMS solely
through modules packaged as Mura CMS plugins and deployed through the Mura CMS plugin installation API,
provided that these modules (a) may only modify the �/trunk/www/plugins/ directory through the Mura CMS
plugin installation API, (b) must not alter any default objects in the Mura CMS database
and (c) must not alter any files in the following directories except in cases where the code contains
a separately distributed license.

/trunk/www/admin/
/trunk/www/tasks/
/trunk/www/config/
/trunk/www/requirements/mura/

You may copy and distribute such a combined work under the terms of GPL for Mura CMS, provided that you include
the source code of that other code when and as the GNU GPL requires distribution of source code.

For clarity, if you create a modified version of Mura CMS, you are not obligated to grant this special exception
for your modified version; it is your choice whether to do so, or to make such modified version available under
the GNU General Public License version 2 �without this exception. �You may, if you choose, apply this exception
to your own modified versions of Mura CMS.
--->
<cfcomponent extends="mura.cfobject" output="false">

<cffunction name="init" access="public" returntype="any" output="false">
<cfargument name="configBean" type="any" required="yes"/>
<cfargument name="utility" type="any" required="yes"/>
<cfargument name="settingsGateway" type="any" required="yes"/>
<cfargument name="settingsDAO" type="any" required="yes"/>
<cfargument name="clusterManager" type="any" required="yes"/>
		<cfset variables.configBean=arguments.configBean />
		<cfset variables.utility=arguments.utility />
		<cfset variables.Gateway=arguments.settingsGateway />
		<cfset variables.DAO=arguments.settingsDAO />
		<cfset variables.clusterManager=arguments.clusterManager />	
		<cfset setSites() />
<cfreturn this />
</cffunction>

<cffunction name="getList" access="public" output="false" returntype="query">
	<cfargument name="sortBy" default="orderno">
	<cfargument name="sortDirection" default="asc">
	<cfset var rs = variables.gateway.getList(arguments.sortBy,arguments.sortDirection) />
	
	<cfreturn rs />
	
</cffunction>

<cffunction name="publishSite" access="public" output="false" returntype="void">
	<cfargument name="siteID" required="yes" default="">
	<cfset var bundleFileName = "">
	<cfset var authToken = "">
	<cfset var i = "">
	<cfset var serverArgs = structNew()>
	<cfset var rsPlugins = application.serviceFactory.getBean("pluginManager").getSitePlugins(arguments.siteID)>
	<cfset var result="">
	<cfif variables.configBean.getValue('deployMode') eq "bundle">
		<cfset bundleFileName = application.serviceFactory.getBean("Bundle").Bundle(
			siteID=arguments.siteID,
			moduleID=ValueList(rsPlugins.moduleID),
			BundleName='deployBundle', 
			includeVersionHistory=false,
			includeTrash=false,
			includeMetaData=true,
			includeMailingListMembers=false,
			includeUsers=false,
			includeFormData=false,
			saveFile=true) />
		
		<cfloop list="#variables.configBean.getServerList()#" index="i" delimiters="^">
			<cfset serverArgs = deserializeJSON(i)>
			<cfset result = pushBundle(siteID, bundleFileName, serverArgs)>
		</cfloop>
		
		<cfquery datasource="#application.configBean.getDatasource()#" username="#application.configBean.getDBUsername()#" password="#application.configBean.getDBPassword()#">
			update tsettings set lastDeployment = #createODBCDateTime(now())#
			where siteID = <cfqueryparam cfsqltype="cf_sql_VARCHAR" value="#arguments.siteID#">
		</cfquery>
		
		<cfset fileDelete(bundleFileName)>
	<cfelse>
		<cfset application.serviceFactory.getBean("publisher").start(arguments.siteid) />
	</cfif>
	<cfset variables.clusterManager.reload() />
	
</cffunction>

<cffunction name="pushBundle" access="public" output="no" returntype="any">
	<cfargument name="siteID" required="yes" default="">
	<cfargument name="bundleFileName" required="yes">
	<cfargument name="serverArgs" required="yes">
	<cfset var bundleArgs = structNew()>
	<cfset var result = "">
	<cfset var authToken="">
	
	<cfinvoke webservice="#serverArgs.serverURL#?wsdl"
		method="login"
		returnVariable="authToken">
		<cfinvokeargument name="username" value="#serverArgs.username#">
		<cfinvokeargument name="password" value="#serverArgs.password#">
		<cfinvokeargument name="siteID" value="#serverArgs.siteID#">
	</cfinvoke>
	
	<cfset bundleArgs.siteID = arguments.siteID />
	<cfset bundleArgs.bundleImportKeyMode = "publish">
	
	<cfif serverArgs.deployMode eq "files">
		<!--- push just files --->
		<cfset bundleArgs.bundleImportContentMode = "none">
	<cfelse>
		<!--- files and content --->
		<cfset bundleArgs.bundleImportContentMode = "all">
	</cfif>
	
	<cfset bundleArgs.bundleImportRenderingMode = "all">
	<cfset bundleArgs.bundleImportPluginMode = "all">
	<cfset bundleArgs.bundleImportMailingListMembersMode = "none">
	<cfset bundleArgs.bundleImportUsersMode = "none">
	<cfset bundleArgs.bundleImportLastDeployment = "">
	<cfset bundleArgs.bundleImportModuleID = "">
	<cfset bundleArgs.bundleImportFormDataMode = "none">
				
	<cfhttp method="post" url="#serverArgs.serverURL#">
		<cfhttpparam name="method" type="url" value="call">
		<cfhttpparam name="serviceName" type="url" value="bundle">
		<cfhttpparam name="methodName" type="url" value="deploy">
		<cfhttpparam name="authToken" type="url" value="#authToken#">
		<cfhttpparam name="args" type="url" value="#serializeJSON(bundleArgs)#">
		<cfhttpparam name="bundleFile" type="file" file="#bundleFileName#">
	</cfhttp>
	
	<cfif cfhttp.FileContent contains "success">
		<cfset result = "Deployment Successful">
	<cfelse>
		<cfset result = cfhttp.FileContent>
	</cfif>
	
	<cfreturn result>
</cffunction>

<cffunction name="saveOrder" access="public" output="false" returntype="void">
<cfargument name="orderno" required="yes" default="">
<cfargument name="orderID" required="yes" default="">

<cfset var i=0/>
	
	<cfif arguments.orderID neq ''>
		<cfloop from="1" to="#listlen(arguments.orderid)#" index="i">
		<cfquery datasource="#variables.configBean.getDatasource()#" username="#variables.configBean.getDBUsername()#" password="#variables.configBean.getDBPassword()#">
		update tsettings set orderno= #listgetat(arguments.orderno,i)# where siteid ='#listgetat(arguments.orderid,i)#'
		</cfquery>
		</cfloop>
	</cfif>
	
	<cfobjectcache action="clear"/>
	
</cffunction>

<cffunction name="saveDeploy" access="public" output="false" returntype="void">
<cfargument name="deploy" required="yes" default="">
<cfargument name="orderID" required="yes" default="">
 <cfset var i=0/>	
	<cfif arguments.deploy neq '' and arguments.orderID neq ''>
		<cfloop from="1" to="#listlen(arguments.orderid)#" index="i">
		<cfquery datasource="#variables.configBean.getDatasource()#" username="#variables.configBean.getDBUsername()#" password="#variables.configBean.getDBPassword()#">
		update tsettings set deploy= #listgetat(arguments.deploy,i)# where siteid ='#listgetat(arguments.orderid,i)#'
		</cfquery>
		</cfloop>
	</cfif>
	
</cffunction>

<cffunction name="read" access="public" output="false" returntype="any">
<cfargument name="siteid" type="string" />

	<cfreturn variables.DAO.read(arguments.siteid) />
	
</cffunction>

<cffunction name="update" access="public" output="false" returntype="any">
	<cfargument name="data" type="struct" />
	
	<cfset var bean=variables.DAO.read(arguments.data.SiteID) />
	<cfset bean.set(arguments.data) />
	
	<cfif structIsEmpty(bean.getErrors())>
		<cfset variables.utility.logEvent("SiteID:#bean.getSiteID()# Site:#bean.getSite()# was updated","mura-settings","Information",true) />
		<cfset variables.DAO.update(bean) />
		<cfset checkForBundle(arguments.data,bean.getErrors())>
		<cfset setSites()/>
	</cfif>

	<cfreturn bean />

</cffunction>

<cffunction name="delete" access="public" output="false" returntype="void">
	<cfargument name="siteid" type="string" />
	
	<cfset var bean=read(arguments.siteid) />
	<cfset variables.utility.logEvent("SiteID:#arguments.siteid# Site:#bean.getSite()# was deleted","mura-settings","Information",true) />
	<cfset variables.DAO.delete(arguments.siteid) />
	<cfset setSites() />
	<cftry>
	<cfset variables.utility.deleteDir("#variables.configBean.getWebRoot()##variables.configBean.getFileDelim()##arguments.siteid##variables.configBean.getFileDelim()#") />
	<cfcatch></cfcatch>
	</cftry>
	<cftry>
	<cfset variables.utility.deleteDir("#variables.configBean.getFileDir()##variables.configBean.getFileDelim()##arguments.siteid##variables.configBean.getFileDelim()#") />
	<cfcatch></cfcatch>
	</cftry>
	<cftry>
	<cfset variables.utility.deleteDir("#variables.configBean.getAssetDir()##variables.configBean.getFileDelim()##arguments.siteid##variables.configBean.getFileDelim()#") />
	<cfcatch></cfcatch>
	</cftry>
</cffunction>

<cffunction name="create" access="public" output="false" returntype="any">
	<cfargument name="data" type="struct" />
	<cfset var rs=""/>
	<cfset var bean=application.serviceFactory.getBean("settingsBean") />
	
	<cfset bean.set(arguments.data) />
	
	<cfif structIsEmpty(bean.getErrors()) and  bean.getSiteID() neq ''>
		
		<cfquery name="rs" datasource="#variables.configBean.getDatasource()#" username="#variables.configBean.getDBUsername()#" password="#variables.configBean.getDBPassword()#">
		select siteid from tsettings where siteid='#bean.getSiteID()#'
		</cfquery>
		
		<cfif rs.recordcount>
			<cfthrow message="The SiteID you entered is already being used.">
			<cfabort>
		</cfif>
		
		<cfif directoryExists(expandPath("/muraWRM/#bean.getSiteID()#"))>
			<cfthrow message="A directory with the same name as the SiteID you entered is already being used.">
		</cfif>
		
		<cfset variables.utility.logEvent("SiteID:#bean.getSiteID()# Site:#bean.getSite()# was created","mura-settings","Information",true) />
		<cfset variables.DAO.create(bean) />
		<cfset variables.utility.copyDir("#variables.configBean.getWebRoot()##variables.configBean.getFileDelim()#default#variables.configBean.getFileDelim()#", "#variables.configBean.getWebRoot()##variables.configBean.getFileDelim()##bean.getSiteID()##variables.configBean.getFileDelim()#") />
		<cfif variables.configBean.getCreateRequiredDirectories()>
			<cfset variables.utility.createRequiredSiteDirectories(bean.getSiteID()) />
		</cfif>
		<cfset checkForBundle(arguments.data,bean.getErrors())>
		<cfset setSites() />
	</cfif>

	<cfreturn bean />
</cffunction>

<cffunction name="setSites" access="public" output="false" returntype="void">
	<cfset var rs="" />
	<cfset var builtSites=structNew()>
	<cfobjectcache action="clear"/>
	<cfset rs=getList() />

	<cfloop query="rs">
		<cfset builtSites['#rs.siteid#']=variables.DAO.read(rs.siteid) />
		<cfif variables.configBean.getCreateRequiredDirectories()>
			<cfset variables.utility.createRequiredSiteDirectories(rs.siteid) />
		</cfif>
 	</cfloop>

	<cfset variables.sites=builtSites>
	
</cffunction>

<cffunction name="getSite" access="public" output="false" returntype="any">
	<cfargument name="siteid" type="string" />
	<cftry>
	<cfreturn variables.sites['#arguments.siteid#'] />
	<cfcatch>
			<cflock name="buildSites" timeout="200">
				<cfif structKeyExists(variables.sites,'#arguments.siteid#')>
					<cfreturn variables.sites['#arguments.siteid#'] />
				<cfelse>
					<cfset setSites() />
				</cfif>
			</cflock>
			<cfif structKeyExists(variables.sites,'#arguments.siteid#')>
				<cfreturn variables.sites['#arguments.siteid#'] />
			<cfelse>
				<cfreturn variables.sites['default'] />
			</cfif>	
	</cfcatch>
	</cftry>
</cffunction>

<cffunction name="siteExists" access="public" output="false" returntype="any">
	<cfargument name="siteid" type="string" />
	
	<cfreturn structKeyExists(variables.sites,arguments.siteid) />

</cffunction>

<cffunction name="getSites" access="public" output="false" returntype="any">
	<cfreturn variables.sites />
</cffunction>

<cffunction name="purgeAllCache" access="public" output="false" returntype="void">
	<cfargument name="broadcast" default="true">
	<cfset var rs=getList()>
	
	<cfloop query="rs">
		<cfset getSite(rs.siteid).getCacheFactory(name="data").purgeAll()/>
		<cfset getSite(rs.siteid).getCacheFactory(name="output").purgeAll()/>
	</cfloop>
	
	<cfif arguments.broadcast>
		<cfset variables.clusterManager.purgeCache(name="all")>
	</cfif>
</cffunction>

<cffunction name="getUserSites" access="public" output="false" returntype="query">
<cfargument name="siteArray" type="array" required="yes" default="#arrayNew(1)#">
<cfargument name="isS2" type="boolean" required="yes" default="false">
	<cfset var rs=""/>
	<cfset var counter=1/>
	<cfset var rsSites=getList(sortby="site")/>
	<cfset var s=0/>
	
	<cfquery name="rs" dbtype="query">
		select * from rsSites
		<cfif arrayLen(arguments.siteArray) and not arguments.isS2>
			where siteid in (
			<cfloop from="1" to="#arrayLen(arguments.siteArray)#" index="s">
			'#arguments.siteArray['#s#']#'
			<cfif counter lt arrayLen(arguments.siteArray)>,</cfif>
			<cfset counter=counter+1>
			</cfloop>)
		<cfelseif not arrayLen(arguments.siteArray) and not arguments.isS2>
		where 0=1
		</cfif>
		
	</cfquery>

	<cfreturn rs />
</cffunction>

<cffunction name="checkForBundle" output="false">
<cfargument name="data">
<cfargument name="errors">
	<cfset var fileManager=getBean("fileManager")>
	<cfset var tempfile="">
	<cfset var deletetempfile=true>
	
	<cfif isDefined("arguments.data.serverBundlePath") and len(arguments.data.serverBundlePath) and fileExists(arguments.data.serverBundlePath)>
		<cfset arguments.data.bundleFile=arguments.data.serverBundlePath>
	</cfif>
	
	<cfif structKeyExists(arguments.data,"bundleFile") and len(arguments.data.bundleFile)>
		<cfif fileManager.isPostedFile(arguments.data.bundleFile)>
			<cffile action="upload" result="tempFile" filefield="bundleFile" nameconflict="makeunique" destination="#variables.configBean.getTempDir()#">
		<cfelse>
			<cfset tempFile=fileManager.emulateUpload(arguments.data.bundleFile)>
			<cfset deletetempfile=false>
		</cfif>
		<cfparam name="arguments.data.bundleImportKeyMode" default="copy">
		<cfparam name="arguments.data.bundleImportContentMode" default="none">
		<cfparam name="arguments.data.bundleImportRenderingMode" default="none">
		<cfparam name="arguments.data.bundleImportPluginMode" default="none">
		<cfparam name="arguments.data.bundleImportMailingListMembersMode" default="none">
		<cfparam name="arguments.data.bundleImportUsersMode" default="none">
		<cfparam name="arguments.data.bundleImportFormDataMode" default="none">
		<cfset restoreBundle(
			"#tempfile.serverDirectory#/#tempfile.serverFilename#.#tempfile.serverFileExt#" , 
			arguments.data.siteID,
			arguments.errors, 
			arguments.data.bundleImportKeyMode,
			arguments.data.bundleImportContentMode, 
			arguments.data.bundleImportRenderingMode,
			arguments.data.bundleImportMailingListMembersMode,
			arguments.data.bundleImportUsersMode,
			arguments.data.bundleImportPluginMode,
			'',
			'',
			arguments.data.bundleImportFormDataMode
			)>
		<cfif deletetempfile>
			<cffile action="delete" file="#tempfile.serverDirectory#/#tempfile.serverFilename#.#tempfile.serverFileExt#">
		</cfif>
	</cfif>
	
</cffunction>

<cffunction name="restoreBundle" output="false">
<cfargument name="bundleFile">
<cfargument name="siteID" default="">
<cfargument name="errors" default="#structNew()#">
<cfargument name="keyMode" default="copy">
<cfargument name="contentMode" default="none">
<cfargument name="renderingMode" default="none">
<cfargument name="mailingListMembersMode" default="none">
<cfargument name="usersMode" default="none">
<cfargument name="pluginMode" default="none">
<cfargument name="lastDeployment" default="">
<cfargument name="moduleID" default="">
<cfargument name="formDataMode" default="none">

    <cfset var sArgs			= structNew()>
	<cfset var config 			= application.configBean />
	<cfset var Bundle			= application.serviceFactory.getBean("bundle") />
	<cfset var publisher 		= application.serviceFactory.getBean("publisher") />
	<cfset var keyFactory		= createObject("component","mura.publisherKeys").init(arguments.keyMode,application.utility)>
	
	<cfset Bundle.restore( arguments.BundleFile)>
	
	<cfset sArgs.fromDSN		= config.getDatasource() />
	<cfset sArgs.toDSN			= config.getDatasource() />
	<cfset sArgs.fromSiteID		= "" />
	<cfset sArgs.toSiteID		= arguments.siteID />
	<cfset sArgs.contentMode			= arguments.contentMode />
	<cfset sArgs.keyMode			= arguments.keyMode />
	<cfset sArgs.renderingMode			= arguments.renderingMode />
	<cfset sArgs.mailingListMembersMode			= arguments.mailingListMembersMode />
	<cfset sArgs.usersMode			= arguments.usersMode />
	<cfset sArgs.formDataMode			= arguments.formDataMode />
	<cfset sArgs.keyFactory		= keyFactory />
	<cfset sArgs.pluginMode		= arguments.pluginMode  />
	<cfset sArgs.Bundle		= Bundle />
	<cfset sArgs.moduleID		= arguments.moduleID />
	<cfset sArgs.errors			= arguments.errors />
	<cfset sArgs.lastDeployment = arguments.lastDeployment />
	
	<cftry>
		<cfset publisher.getToWork( argumentCollection=sArgs )>
		
		<cfif len(arguments.siteID)>
			<cfset getSite(arguments.siteID).getCacheFactory(name="output").purgeAll()>
			<cfif sArgs.contentMode neq "none">
				<cfset getSite(arguments.siteID).getCacheFactory(name="data").purgeAll()>
				<cfset getBean("contentUtility").updateGlobalMaterializedPath(siteID=arguments.siteID)>
			</cfif>
			<cfif sArgs.pluginMode neq "none">
				<cfset getBean("pluginManager").loadPlugins()>
			</cfif>	
		</cfif>
	
	<cfcatch>
		
		<cfset arguments.errors.message="The bundle was not successfully imported:<br/>ERROR: " & cfcatch.message>
		<cfif findNoCase("duplicate", arguments.errors.message)>
			<cfset  arguments.errors.message= arguments.errors.message & "<br/>HINT: This error is most often caused by 'Maintaining Keys' when the bundle data already exists within another site in the current Mura instance.">
		</cfif>
		<cfif isDefined("cfcatch.sql") and len(cfcatch.sql)>
			<cfset  arguments.errors.message= arguments.errors.message & "<br/>SQL: " & cfcatch.sql>
		</cfif>
		
		<cfif isDefined("cfcatch.detail") and len(cfcatch.detail)>
			<cfset  arguments.errors.message= arguments.errors.message & "<br/>DETAIL: " & cfcatch.detail>
		</cfif>
	</cfcatch>
	</cftry>
	<cfreturn  arguments.errors>
</cffunction>

<cffunction name="isBundle" output="false">
	<cfargument name="BundleFile">
	<cfset var rs=createObject("component","mura.Zip").List(zipFilePath="#arguments.BundleFile#")>

	<cfquery name="rs" dbType="query">
		select entry from rs where entry in ('sitefiles.zip','pluginfiles.zip','filefiles.zip','pluginfiles.zip')
	</cfquery>
	<cfreturn rs.recordcount>
</cffunction>	

<cffunction name="createCacheFactory" output="false">
	<cfargument name="capacity" required="true" default="0">
	<cfargument name="freeMemoryThreshold" required="true" default="60">
	
	<cfif not arguments.capacity>
		<cfreturn createObject("component","mura.cache.cacheFactory").init(freeMemoryThreshold=arguments.freeMemoryThreshold)>
	<cfelse>
		<cfreturn createObject("component","mura.cache.cacheFactoryLRU").init(capacity=arguments.capacity, freeMemoryThreshold=arguments.freeMemoryThreshold)>
	</cfif>
	
</cffunction>

</cfcomponent>