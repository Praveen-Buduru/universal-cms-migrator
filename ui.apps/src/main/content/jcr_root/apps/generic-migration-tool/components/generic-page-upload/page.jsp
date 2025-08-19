<%--
  ADOBE CONFIDENTIAL
  ___________________

  Copyright 2015 Adobe
  All Rights Reserved.

  NOTICE: All information contained herein is, and remains
  the property of Adobe and its suppliers, if any. The intellectual
  and technical concepts contained herein are proprietary to Adobe
  and its suppliers and are protected by all applicable intellectual
  property laws, including trade secret and copyright laws.
  Dissemination of this information or reproduction of this material
  is strictly forbidden unless prior written permission is obtained
  from Adobe.
--%><%
%><%@ include file="/libs/granite/ui/global.jsp" %><%
%><%@ page session="false"
          import="java.io.UnsupportedEncodingException,
                  java.net.URLDecoder,
                  java.net.URLEncoder,
                  java.util.Arrays,
                  java.util.Collection,
                  java.util.Iterator,
                  java.util.List,
                  java.util.Map,
                  java.util.stream.Collectors,
                  org.apache.sling.api.SlingHttpServletRequest,
                  org.apache.commons.collections4.IteratorUtils,
                  org.apache.commons.lang3.StringUtils,
                  org.apache.sling.resourcemerger.api.ResourceMergerService,
                  org.apache.sling.commons.json.JSONObject,
                  org.apache.sling.commons.json.io.JSONStringer,
                  com.adobe.granite.security.user.UserProperties,
                  com.adobe.granite.security.user.UserPropertiesManager,
                  com.adobe.granite.security.user.UserPropertiesService,
                  org.apache.jackrabbit.api.security.user.Authorizable,
                  com.adobe.granite.i18n.LocaleUtil,
                  com.adobe.granite.ui.components.AttrBuilder,
                  com.adobe.granite.ui.components.Config,
                  com.adobe.granite.ui.components.ExpressionHelper,
                  com.adobe.granite.ui.components.ExpressionResolver,
                  com.adobe.granite.ui.components.FilteringResourceWrapper,
		   com.adobe.granite.omnisearch.api.core.OmniSearchService,
                  com.adobe.granite.ui.components.Tag" %><%--###
Page
====

.. granite:servercomponent:: /libs/granite/ui/components/shell/page

   The generic page to render Shell.

   It also supports :doc:`resource filtering using FilteringResourceWrapper </jcr_root/libs/granite/ui/docs/server/resourcehiding>` and acts as its container.

   It has the following content structure:

   .. gnd:gnd::

      [granite:ShellPage]

      /**
       * A general purpose ID to uniquely identify the console.
       *
       * The recommended value is hierarchical separated by "-".
       * e.g. "cq-commerce-report"
       */
      - consoleId (String)

      /**
       * To render the title of the page (``<title>``), resource at ``head/title`` is first inspected.
       * If it doesn't exist, this property is used accordingly; otherwise do nothing.
       * i.e. the title at ``head/title`` is included naturally.
       */
      - jcr:title (String)

      /**
       * To redirect the page, this resource can be specified.
       * It will be included, where the redirect can be performed.
       */
      + redirector

      /**
       * A folder to specify the content of ``<head>`` of the page.
       * Its child resources are iterated and included as is.
       */
      + head

      /**
       * The component to render the title.
       *
       * This is optional, and if not specified, the title header is not displayed.
       * If the title is just a simple string, :doc:`../title/index` can be used.
       *
       * The only requirement of the component is to generate a simple text without any wrapping markup.
       * E.g. To have a title of "My Page", just make the component do something like ``out.print("My Page")``.
       *
       * Note if the title and breadcrumbs are provided, only the breadcrumbs will be generated.
       */
      + title

      /**
       * The data source for the list of breadcrumbs.
       *
       * This is optional, and if not specified, the breadcrumbs are not displayed.
       *
       * Note that only the breadcrumbs can be rendered or the title, not both.  The breadcrumbs
       * will take prescience over the title if both are provided.
       */
      + breadcrumbs

      /**
       * The folder for the actions applicable in the context of the whole page.
       */
      + actions (granite:ShellPageActions)

      /**
       * The path to the omnisearch configuration associated with the console.
       *
       * e.g. ``/libs/granite/omnisearch/content/metadata/site``
       */
      - omnisearchLocationPath (StringEL)

      /**
       * A folder to specify the panels of the rail.
       */
      + rails (granite:ShellCollectionPageRails)

      /**
       * The actual content of the page.
       */
      + content

      [granite:ShellPageActions]

      /**
       * The folder for primary actions.
       *
       * The action can be any action component such as :doc:`/jcr_root/libs/granite/ui/components/coral/foundation/button/index`,
       * :doc:`/jcr_root/libs/granite/ui/components/coral/foundation/anchorbutton/index`,
       * :doc:`/jcr_root/libs/granite/ui/components/coral/foundation/pulldown/index`,
       * :doc:`/jcr_root/libs/granite/ui/components/coral/foundation/collection/index`.
       *
       * The ``actionBar`` variant of the components above SHOULD be used, unless ``primary`` variant is used.
       */
      + primary

      /**
       * The folder for secondary actions.
       *
       * The action can be any action component such as :doc:`/jcr_root/libs/granite/ui/components/coral/foundation/button/index`,
       * :doc:`/jcr_root/libs/granite/ui/components/coral/foundation/anchorbutton/index`,
       * :doc:`/jcr_root/libs/granite/ui/components/coral/foundation/pulldown/index`,
       * :doc:`/jcr_root/libs/granite/ui/components/coral/foundation/collection/index`.
       *
       * The ``actionBar`` variant of the components above SHOULD be used, unless ``primary`` variant is used.
       */
      + secondary

      [granite:ShellCollectionPageRails]

      /**
       * ``true`` to activate the rail initially.
       *
       * Note that you need to also set ``active`` property of the rail panel to ``true`` accordingly.
       */
      - active (BooleanEL)

      /**
       * The child resources are considered as the panels, where each MUST be a :doc:`../../coral/foundation/panel/railpanel/index` (or its derivative).
       */
      + '*' (granite:PanelRailPanel)


   Example::

      + mypage
        - sling:resourceType = "granite/ui/components/shell/page"
        - jcr:title = "My Page"
        + content
          - sling:resourceType = "granite/ui/components/coral/foundation/container"
###--%><%

Config cfg = cmp.getConfig();
ExpressionHelper ex = cmp.getExpressionHelper();

if (!cfg.get("noMerge", false)) {
    ResourceMergerService resourceMerger = sling.getService(ResourceMergerService.class);
    if (resourceMerger != null) {
        Resource uiResource = resourceMerger.getMergedResource(resource);
        if (uiResource != null) {
            resource = uiResource;
            cfg = new Config(resource);
        }
    }
}

resource = new FilteringResourceWrapper(resource, sling.getService(ExpressionResolver.class), slingRequest);

Resource redirector = resource.getChild("redirector");
if (redirector != null) {
    %><sling:include resource="<%= redirector %>" /><%

    if (response.isCommitted()) {
        return;
    }
}

// GRANITE-8258: Force the header to bypass the compatibility mode on intranet sites
response.setHeader("X-UA-Compatible", "IE=edge");

String consoleId = cfg.get("consoleId", String.class);

AttrBuilder htmlAttrs = new AttrBuilder(request, xssAPI);
htmlAttrs.addClass("skipCoral2Validation");
htmlAttrs.add("lang", LocaleUtil.toRFC4646(request.getLocale()).toLowerCase());
htmlAttrs.add("data-i18n-dictionary-src", request.getContextPath() + "/libs/cq/i18n/dict.{+locale}.json");

Authorizable auth = resourceResolver.adaptTo(Authorizable.class);
UserPropertiesManager upm = resourceResolver.adaptTo(UserPropertiesManager.class);
UserProperties userPreferences = upm.getUserProperties(auth, UserPropertiesService.PREFERENCES_PATH);
String userPreferencesPath = auth.getPath() + "/" + UserPropertiesService.PREFERENCES_PATH;

%><!DOCTYPE html>
<html <%= htmlAttrs %>>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="shortcut icon" href="<%= request.getContextPath() %>/libs/granite/core/content/login/favicon.ico"><%

    String title = cfg.get("jcr:title", String.class);
    Resource headTitleRes = resource.getChild("head/title");
    if (headTitleRes == null) {
        if (title != null) {
            %><title><%= outVar(xssAPI, i18n, title) %></title><%
        }
    } else {
        %><sling:include resource="<%= headTitleRes %>" /><%
    }

    Resource globalHead = resourceResolver.getResource("/mnt/overlay/granite/ui/content/globalhead");
    if (globalHead != null) {
        for (Iterator<Resource> it = globalHead.listChildren(); it.hasNext();) {
            %><sling:include resource="<%= it.next() %>" /><%
        }
    }

    AttrBuilder userPrefAttrs = new AttrBuilder(request, xssAPI);
    userPrefAttrs.add("name", "user.preferences");
    userPrefAttrs.add("content", getPreferencesJSON(userPreferences));
    userPrefAttrs.addHref("data-foundation-preference-action", userPreferencesPath);

    %><meta <%= userPrefAttrs %>>
    <%-- <meta name="user.preferences.winmode"> is deprecated, use foundation-preference instead --%>
    <meta name="user.preferences.winmode" content="<%= xssAPI.encodeForHTMLAttr(getPreference(userPreferences, "winMode", "multi")) %>"><%

    if (cfg.get("coral2", false)) {
        %><ui:includeClientLib categories="coralui2,granite.ui.coral.foundation,granite.ui.coral.foundation.addon.coral2,granite.ui.shell" /><%
    } else {
        %><ui:includeClientLib categories="coralui3,granite.ui.coral.foundation,granite.ui.shell" /><%
    }

    String[] pageHierarchy = getPageHierarchy(consoleId);

    if (pageHierarchy == null) {
        pageHierarchy = getPageHierarchyByTitle(!StringUtils.isBlank(title) ? title : resource.getPath());
    }

    String assetId = StringUtils.isNotEmpty(request.getParameter("item"))
        ? request.getParameter("item")
        : slingRequest.getRequestPathInfo().getSuffix();

    JSONObject trackingPage = new JSONObject();
    trackingPage.put("hierarchy", pageHierarchy[0]);
    trackingPage.put("name", pageHierarchy[1]);
    if (StringUtils.isNotEmpty(assetId)) {
        trackingPage.put("assetId", assetId);
    }

    %><meta name="foundation.tracking.page" content="<%= xssAPI.encodeForHTMLAttr(trackingPage.toString()) %>"><%

    String omnisearchLocationPath = ex.getString(cfg.get("omnisearchLocationPath", String.class));
    Resource omnisearchConfigResource = resourceResolver.getResource(omnisearchLocationPath);
    if (omnisearchConfigResource != null) {
        OmniSearchService omnisearchService = sling.getService(OmniSearchService.class);
        // check if OmnisearchHanlder is present
        if (omnisearchService.getModuleConfiguration(resourceResolver, omnisearchConfigResource.getName()) != null) {

            ValueMap props = omnisearchConfigResource.getValueMap();

            %><meta class="granite-omnisearch-location"
                    data-granite-omnisearch-location-value="<%= xssAPI.encodeForHTMLAttr(omnisearchConfigResource.getName())%>"
                    data-granite-omnisearch-location-label="<%= xssAPI.encodeForHTMLAttr(i18n.getVar(props.get("jcr:title", "")))%>"><%
        }
    }

    AttrBuilder omnisearchSrcAttrs = new AttrBuilder(request, xssAPI);
    omnisearchSrcAttrs.addClass("granite-omnisearch-src");
    omnisearchSrcAttrs.add("data-granite-omnisearch-src", request.getContextPath() + "/mnt/overlay/granite/ui/content/shell/omnisearch.{location}.html");
    omnisearchSrcAttrs.addHref("data-granite-omnisearch-search-url", "/aem/search.html");

    %><meta <%= omnisearchSrcAttrs %>><%

    Resource head = resource.getChild("head");
    if (head != null) {
        for (Iterator<Resource> it = head.listChildren(); it.hasNext();) {
            Resource item = it.next();

            if (item.getName().equals("title")) {
                continue;
            }

            %><sling:include resource="<%= item %>" /><%
        }
    }
%></head><%
// Flush head so that the browser can start downloading the clientlibs
response.flushBuffer();

Resource rails = resource.getChild("rails");
// We generate a cookie key unique per console
String railSaveKey = "rail-" + consoleId;
String panelWidthSaveKey = "panel-width-" + consoleId;
String savedRailTarget = getSavedCookieValue(slingRequest, railSaveKey);
String savedPanelWidth = getSavedCookieValue(slingRequest, panelWidthSaveKey);
boolean savedRailTargetFound = false;
boolean hasActiveRail = rails != null && cmp.getExpressionHelper().getBoolean(rails.getValueMap().get("active", "false"));
int minRailSize = 250;
int minContentSize = 100;
%><body class="coral--light">
<coral-shell>
    <coral-shell-header role="region" aria-label="<%= xssAPI.encodeForHTMLAttr(i18n.get("Header Bar")) %>"
                        class="coral--dark granite-shell-header"><%
        String navigationUrl = "/mnt/overlay/granite/ui/content/shell/globalnav.html";
        if (consoleId != null) {
            navigationUrl += "?consoleId=" + URLEncoder.encode(consoleId, "utf-8");
        }

        AttrBuilder headerHome = new AttrBuilder(request, xssAPI);
        headerHome.addClass("globalnav-toggle");
        headerHome.addHref("data-globalnav-toggle-href", navigationUrl);

        %><coral-shell-header-home <%= headerHome %>>
            <a is="coral-shell-homeanchor" icon="adobeExperienceManagerColor" href="#" id="globalNavHeader" aria-expanded=false><%= xssAPI.encodeForHTML(i18n.get("Adobe Experience Manager")) %></a>
        </coral-shell-header-home>

        <coral-shell-header-actions>
            <coral-shell-menubar><%
                final Resource headerActions = resourceResolver.getResource("/mnt/overlay/granite/ui/content/shell/header/actions");
                if (headerActions != null) {
                    for (Iterator<Resource> it = headerActions.listChildren(); it.hasNext();) {
                        %><sling:include resource="<%= it.next() %>" /><%
                    }
                }
            %></coral-shell-menubar>
        </coral-shell-header-actions>
    </coral-shell-header>

    <coral-shell-content class="foundation-content" role="main">
        <div class="foundation-content-current foundation-layout-util-maximized-alt">
            <div class="foundation-layout-panel">
                <div class="foundation-layout-panel-header"><%
                    Resource titleRes = resource.getChild("title");
                    Resource breadcrumbs = resource.getChild("breadcrumbs");
                    if (titleRes != null || breadcrumbs != null || rails != null) {
                        %><betty-titlebar>
                            <betty-titlebar-title><%
                                    if (breadcrumbs != null) {
                                        List<Resource> crumbs = IteratorUtils.toList(cmp.asDataSource(breadcrumbs).iterator());

                                        if (!crumbs.isEmpty()) {
                                            %><betty-breadcrumbs class="granite-collection-navigator"><%
                                                for (int j = 0; j < crumbs.size(); j++) {
                                                    Resource item = (Resource) crumbs.get(j);
                                                    Config itemCfg = new Config(item);

                                                    AttrBuilder itemAttrs = new AttrBuilder(request, xssAPI);
                                                    String navigatorCollectionid = itemCfg.get("path", String.class);
                                                    if (navigatorCollectionid != null) {
                                                        itemAttrs.add("data-granite-collection-navigator-collectionid", navigatorCollectionid);
                                                    } else {
                                                        itemAttrs.add("data-granite-collection-navigator-href", itemCfg.get("href", String.class));
                                                    }
                                                    %><betty-breadcrumbs-item <%= itemAttrs %>><%= xssAPI.encodeForHTML(itemCfg.get("title")) %></betty-breadcrumbs-item><%
                                                }
                                            %></betty-breadcrumbs><%
                                        }
                                    } else {
                                        if (titleRes != null) {
                                            %><span class="granite-title" role="heading" aria-level="1"><sling:include resource="<%= titleRes %>" /></span><%
                                        }
                                    }
                            %></betty-titlebar-title>
                            <betty-titlebar-primary><%
                                if (rails != null) {
                                    %><coral-cyclebutton class="granite-toggleable-control"
                                                         icon="railLeft"
                                                         displaymode="icontext"
                                                         data-granite-toggleable-control-savekey="<%= xssAPI.encodeForHTMLAttr(railSaveKey) %>">
                                        <coral-cyclebutton-item
                                            displaymode="icon"
                                            data-foundation-command="`"
                                            data-granite-toggleable-control-target="#shell-page-rail"
                                            data-granite-toggleable-control-action="hide"><%= xssAPI.encodeForHTML(i18n.get("Content Only")) %></coral-cyclebutton-item><%

                                        // we map all rail items to the numbers in the keyboard using control + {index}
                                        int railItemIndex = 1;
                                        for (Iterator<Resource> it = rails.listChildren(); it.hasNext(); railItemIndex++) {
                                            Resource item = it.next();
                                            if (cmp.getRenderCondition(item, true).check()) {
                                                Config itemCfg = new Config(item);
                                                AttrBuilder itemAttrs = new AttrBuilder(request, xssAPI);

                                                // we stop once we reach 9 since all available numbers have been used
                                                if (railItemIndex < 10) {
                                                    itemAttrs.add("data-foundation-command", "alt+" + railItemIndex);
                                                }

                                                if (item.getName().equals("omnisearchfilter")) {
                                                    itemAttrs.add("data-granite-toggleable-control-action", "hide");
                                                    itemAttrs.add("data-granite-toggleable-control-target", "#shell-collectionpage-rail");
                                                    itemAttrs.add("data-granite-omnisearch-filter", "");
                                                } else {
                                                    String href = ex.getString(itemCfg.get("href", String.class));

                                                    itemAttrs.add("icon", itemCfg.get("icon", String.class));

                                                    if (href != null) {
                                                        itemAttrs.add("data-granite-toggleable-control-action", "navigate");
                                                        itemAttrs.addHref("data-granite-toggleable-control-href", href);
                                                    } else {
                                                        String railPanelTarget = ".shell-collectionpage-rail-panel[data-shell-collectionpage-rail-panel='" + item.getName() + "']";

                                                        itemAttrs.add("data-granite-toggleable-control-action", "show");
                                                        itemAttrs.add("data-granite-toggleable-control-target", railPanelTarget);
                                                    }

                                                    itemAttrs.addSelected(itemCfg.get("active", false));
                                                    if (!hasActiveRail && savedRailTarget != null && savedRailTarget.equals(item.getName())) {
                                                        itemAttrs.addSelected(true);
                                                        savedRailTargetFound = true;
                                                    }
                                                }
                                                %><coral-cyclebutton-item <%= itemAttrs %>><%= outVar(xssAPI, i18n, itemCfg.get("jcr:title", String.class)) %></coral-cyclebutton-item><%
                                            }
                                        }
                                    %></coral-cyclebutton><%
                                }

                                Resource primary = resource.getChild("actions/primary");
                                if (primary != null) {
                                    for (Iterator<Resource> it = primary.listChildren(); it.hasNext();) {
                                        %><sling:include resource="<%= it.next() %>" /><%
                                    }
                                }
                            %></betty-titlebar-primary>
                            <betty-titlebar-secondary><%
                                Resource secondary = resource.getChild("actions/secondary");
                                if (secondary != null) {
                                    for (Iterator<Resource> it = secondary.listChildren(); it.hasNext();) {
                                        %><sling:include resource="<%= it.next() %>" /><%
                                    }
                                }
                            %></betty-titlebar-secondary>
                        </betty-titlebar><%
                    }
                %></div>
                <div class="foundation-layout-panel-bodywrapper">
                    <div class="foundation-layout-panel-body"><%
                        if (rails != null) {
                            AttrBuilder railAttrs = new AttrBuilder(request, xssAPI);
                            railAttrs.add("id", "shell-page-rail");
                            railAttrs.addClass("foundation-toggleable foundation-layout-panel-rail granite-rail");
                            railAttrs.addClass("foundation-container-resizable");
                            railAttrs.add("data-granite-layout-panel-save-key", panelWidthSaveKey);
                            railAttrs.add("data-granite-layout-panel-min-width", minRailSize);

                            String panelStyle = "";
                            if (savedPanelWidth != null && !savedPanelWidth.isEmpty()) {
                                panelStyle = "width: " + savedPanelWidth + "px;";
                            }
                            if (cmp.getExpressionHelper().getBoolean(rails.getValueMap().get("active", "false")) || savedRailTargetFound) {
                                railAttrs.addClass("foundation-layout-panel-rail-active");
                                railAttrs.addClass("foundation-layout-panel-rail-activate-panel");
                            } else {
                                if (savedPanelWidth != null && !savedPanelWidth.isEmpty()) {
                                    panelStyle = panelStyle + "margin-left: -" + savedPanelWidth + "px;";
                                }
                            }
                            railAttrs.add("style", panelStyle);

                            %><div <%= railAttrs %>>
                                <coral-panelstack maximized><%
                                    for (Iterator<Resource> it = rails.listChildren(); it.hasNext();) {
                                        Resource item = it.next();
                                        AttrBuilder itemAttrs = new AttrBuilder(request, xssAPI);
                                        itemAttrs.addClass("shell-collectionpage-rail-panel");
                                        itemAttrs.add("data-shell-collectionpage-rail-panel", item.getName());
                                        if (!hasActiveRail && savedRailTarget != null && savedRailTarget.equals(item.getName())) {
                                            itemAttrs.addSelected(true);
                                        }
                                        cmp.include(item, new Tag(itemAttrs));
                                    }
                                %></coral-panelstack>
                                <div class="foundation-container-resizable-handle"></div>
                            </div><%
                        }
                        AttrBuilder panelContentAttrs = new AttrBuilder(request, xssAPI);
                        panelContentAttrs.add("data-granite-layout-content-min-width", minContentSize);
                        %>
						<%-- Progress Bar Below Title --%>
						<div class="foundation-layout-panel-content" <%= panelContentAttrs %>><%
                            Resource content = resource.getChild("content");
                            if (content != null) {
                                %><sling:include resource="<%= content %>" /><%
                            }
                        %>
                    <div id="downloadSection" style="display: none; margin-top: 10px;">
                        <a href="#" id="downloadReportLink" class="blink">Click Here to download the migration report</a>
                    </div></div>
                    </div>
                </div>
            </div>
        </div>
    </coral-shell-content>
</coral-shell>
<a class="foundation-toggleable-control u-coral-screenReaderOnly"
   aria-hidden="true"
   data-foundation-command="?"
   data-foundation-toggleable-control-src="<%= request.getContextPath() %>/mnt/overlay/granite/ui/content/shell/shortcutsdialog.html">
</a>
<%
Resource globalFooter = resourceResolver.getResource("/mnt/overlay/granite/ui/content/globalfooter");
if (globalFooter != null) {
    for (Iterator<Resource> it = globalFooter.listChildren(); it.hasNext();) {
        %><sling:include resource="<%= it.next() %>" /><%
    }
}
%></body>
</html><%
%><%!
private String getSavedCookieValue(SlingHttpServletRequest request, String key) {
    try {
        Cookie cookie = request.getCookie(key);

        if (cookie == null) {
            return null;
        }

        return URLDecoder.decode(cookie.getValue(), "utf-8");
    } catch (UnsupportedEncodingException impossible) {
        throw new RuntimeException(impossible);
    }
}

private String getPreferencesJSON(UserProperties props) throws Exception {
    JSONStringer json = new JSONStringer();
    json.object();

    if (props != null) {
        for (String name : props.getPropertyNames()) {
            Object v = props.getProperty(name, null, Object.class); // No conversion, use Object.class
            if (v != null) {
                json.key(name).value(v);
            }
        }
    }

    json.endObject();
    return json.toString();
}

private String getPreference(UserProperties props, String name, String defaultValue) throws Exception {
    if (props != null) {
        return props.getProperty(name, defaultValue, String.class);
    } else {
        return defaultValue;
    }
}

/**
 * Return the hierarchy and name of the current page based on consoleId.
 *
 * If the first part of the consoleId is "cq" or "granite", the part is ignored.
 *
 * Example
 *
 * ----------------------------------------------
 * consoleId    | result
 * ----------------------------------------------
 * cq-sites     | hierarchy = sites, name = sites
 * cq-sites-abc | hierarchy = sites, name = abc
 * ----------------------------------------------
 */
private String[] getPageHierarchy(String consoleId) {
    if (StringUtils.isBlank(consoleId)) {
        return null;
    }

    String[] parts = consoleId.split("-");

    int startIndex = 0;

    String namespace = parts[0];
    if (namespace.equals("cq") || namespace.equals("granite")) {
        startIndex = 1;
    }

    if (startIndex >= parts.length) {
        return null;
    }

    String name = parts[parts.length - 1];

    String hierarchy;
    if (startIndex == parts.length - 1) {
        hierarchy = name;
    } else {
        hierarchy = StringUtils.join(parts, ':', startIndex, parts.length - 1);
    }

    return new String[] { hierarchy, name };
}

/**
 * Returns the hierarchy and name of the current page based on the title.
 */
private String[] getPageHierarchyByTitle(String title) {
    String[] parts = title.split("\\|");

    String namespace = parts[0];
    if (namespace.startsWith("AEM")) {
        parts[0] = namespace.replaceFirst("AEM", "");
    }

    String name = parts[parts.length - 1].trim().toLowerCase();

    String hierarchy;
    if (parts.length == 1) {
        hierarchy = name;
    } else {
    	hierarchy = Arrays.stream(parts)
            .limit(parts.length - 1)
            .map(String::trim)
            .map(String::toLowerCase)
            .collect(Collectors.joining(":"));
    }

    return new String[] { hierarchy, name };
}
%>

<style>
    /* Input Styles (for demo purposes) */
    .input-section {
        max-width: 700px;
        margin: 20px auto;
        display: flex;
        justify-content: space-between;
        gap: 10px;
    }

    .input-section input {
        flex: 1;
        padding: 6px 10px;
        border: 1px solid #ccc;
        border-radius: 4px;
    }

    .foundation-layout-util-maximized-container.foundation-form{
        overflow: hidden !important;
    }

    .foundation-layout-panel-bodywrapper{
    background-image: linear-gradient(rgba(0, 0, 0, 0.4), rgba(0, 0, 0, 0.4)),  /* dark tint */
    url("/etc.clientlibs/generic-migration-tool/clientlibs/clientlib-base/resources/background.png");
  background-repeat: no-repeat;
  background-size: cover;
  background-position: center;
  height: 100vh;
  position: relative;
    }
    .coral--light .coral-Heading.coral-Heading--2{
        font-weight: bold;
        color: #ffffff !important;
    }

    .coral--light .coral-Form-fieldlabel{
        color: #ffffff !important;
    }
    .coral--light ._coral-Button--primary {
        background-color: transparent;
        border-color: #ffffff;
        color: #ffffff;
        z-index: 2;
    }

    #downloadSection{
        text-align: center;
        font-weight: bold;
        font-style: italic;
        margin-top: -152px !important;
        margin-left: 170px;
        position: relative;
        z-index: 1;
        a{
            color: #ffffff;
            text-decoration: underline;
        }
    }

    .blink {
        animation: blink-animation 1s steps(2, start) infinite;
        -webkit-animation: blink-animation 1s steps(2, start) infinite;
        color: red; /* optional */
        font-weight: bold; /* optional */
        text-decoration: none; /* optional */
        }

        .blink:hover {
            animation: none;
            -webkit-animation: none;
        }

        @keyframes blink-animation {
        to {
            visibility: hidden;
        }
        }
.foundation-content{
    .foundation-content-current.foundation-layout-util-maximized-alt{
        .foundation-layout-panel{
            .foundation-layout-panel-header{
                display: none !important;
            }
        }
    }
}
</style>
