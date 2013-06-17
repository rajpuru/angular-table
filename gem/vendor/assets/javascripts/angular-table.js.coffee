# author: Samuel Mueller http://github.com/ssmm

angular.module "angular-table", []

angular.module("angular-table").service "attributeExtractor", () ->
  {
    extractWidth: (classes) ->
      width = /([0-9]+px)/i.exec classes
      if width then width[0] else ""

    isSortable: (classes) ->
      sortable = /(sortable)/i.exec classes
      if sortable then true else false

    extractTitle: (td) ->
      td.attr("title") || td.attr("attribute")

    extractAttribute: (td) ->
      td.attr("attribute")

  }

angular.module("angular-table").directive "atTable", ["attributeExtractor", (attributeExtractor) ->

  capitaliseFirstLetter = (string) ->
    string.charAt(0).toUpperCase() + string.slice(1)

  constructHeader = (element) ->
    thead = element.find "thead"

    if thead[0]
      tr = thead.find "tr"
      existing_ths = {}
      for th in tr.find "th"
        th = angular.element(th)
        existing_ths[th.attr("attribute")] = th.html()

      tr.remove()
      tr = $("<tr></tr>")

      tds = element.find("td")
      for td in tds
        td = angular.element(td)
        attribute = attributeExtractor.extractAttribute(td)
        th = $("<th style='cursor: pointer; -webkit-user-select: none;'></th>")
        title = existing_ths[attribute] || capitaliseFirstLetter(attributeExtractor.extractTitle(td))
        th.html("#{title}")

        sortable = td[0].attributes.sortable || attributeExtractor.isSortable(td.attr("class"))
        if sortable
          th.attr("ng-click", "predicate = '#{attribute}'; descending = !descending;")
          icon = angular.element("<i style='margin-left: 10px;'></i>")
          icon.attr("ng-class", "getSortIcon('#{attribute}')")
          th.append(icon)

        width = attributeExtractor.extractWidth(td.attr("class"))
        th.attr("width", width)
        tr.append(th)

      thead.append tr

  validateInput = (attributes) ->
    if attributes.pagination and attributes.list
      throw "You can not specify a list if you have specified a pagination. The list defined for the pagnination will automatically be used."
    if not attributes.pagination and not attributes.list
      throw "Either a list or pagination must be specified."

  setupTr = (element, repeatString) ->
    tbody = element.find "tbody"
    tr = tbody.find "tr"
    tr.attr("ng-repeat", repeatString)
    tbody


  StandardSetup = (attributes) ->
    @repeatString = "item in #{attributes.list} | orderBy:predicate:descending"
    @compile = (element, attributes, transclude) ->
      setupTr element, @repeatString

    @link = () ->
    return

  PaginationSetup = (attributes) ->
    @repeatString = "item in #{attributes.pagination}.list | limitTo:fromPage() | limitTo:toPage() | orderBy:predicate:descending"

    @compile = (element, attributes, transclude) ->
      tbody = setupTr element, @repeatString

      if typeof attributes.fillLastPage != "undefined"
        tds = element.find("td")
        tdString = ""
        for td in tds
          tdString += "<td>{{item}}&nbsp;</td>"

        fillerTr = angular.element("<tr>#{tdString}</tr>")
        fillerTr.attr("ng-repeat", "item in #{attributes.pagination}.getFillerArray() ")

        tbody.append(fillerTr)

    @link = ($scope, $element, $attributes) ->
      paginationName = attributes.pagination
      $scope.fromPage = () ->
        if $scope[paginationName] then $scope[paginationName].fromPage()

      $scope.toPage = () ->
        if $scope[paginationName] then $scope[paginationName].itemsPerPage

    return

  createSetup = (attributes) ->
    validateInput attributes
    if attributes.list
      return new StandardSetup(attributes)
    if attributes.pagination
      return new PaginationSetup(attributes)
    return

  {
    restrict: "AC"
    scope: true
    compile: (element, attributes, transclude) ->
      setup = createSetup attributes
      constructHeader(element)
      setup.compile(element, attributes, transclude)
      {
        post: ($scope, $element, $attributes) ->

          $scope.getSortIcon = (predicate) ->
            return "icon-minus" if predicate != $scope.predicate
            if $scope.descending then "icon-chevron-down" else "icon-chevron-up"

          setup.link($scope, $element, $attributes)
      }
  }
]

angular.module("angular-table").directive "atImplicit", ["attributeExtractor", (attributeExtractor) ->
  {
    restrict: "AC"
    compile: (element, attributes, transclude) ->
      attribute = attributeExtractor.extractAttribute element
      element.append "{{item.#{attribute}}}"
  }
]

angular.module("angular-table").directive "atPagination", ["attributeExtractor", (attributeExtractor) ->
  {
    replace: true
    restrict: "E"
    template: "
      <div class='pagination' style='margin: 0px;'>
        <ul>
          <li ng-class='{disabled: currentPage <= 0}'>
            <a href='' ng-click='goToPage(currentPage - 1)'>&laquo;</a>
          </li>
          <li ng-class='{active: currentPage == page}' ng-repeat='page in pages'>
            <a href='' ng-click='goToPage(page)'>{{page + 1}}</a>
          </li>
          <li ng-class='{disabled: currentPage >= numberOfPages - 1}'>
            <a href='' ng-click='goToPage(currentPage + 1); normalize()'>&raquo;</a>
          </li>
        </ul>
      </div>"
    scope: {
      itemsPerPage: "@"
      instance: "="
      list: "="
    }
    link: ($scope, $element, $attributes) ->

      $scope.instance = $scope
      $scope.currentPage = 0

      $scope.update = () ->
        $scope.currentPage = 0
        if $scope.list
          if $scope.list.length > 0
            $scope.numberOfPages = Math.ceil($scope.list.length / $scope.itemsPerPage)
            $scope.pages = for x in [0..($scope.numberOfPages - 1)]
              x
          else
            $scope.numberOfPages = 0
            $scope.pages = []
          $scope.list = $scope.list

      $scope.fromPage = () ->
        if $scope.list
          $scope.itemsPerPage * $scope.currentPage - $scope.list.length

      $scope.getFillerArray = () ->
        if $scope.currentPage == $scope.numberOfPages - 1
          itemCountOnLastPage = $scope.list.length % $scope.itemsPerPage
          if itemCountOnLastPage != 0
            fillerLength = $scope.itemsPerPage - itemCountOnLastPage - 1
            x for x in [($scope.list.length)..($scope.list.length + fillerLength)]
          else
            []


      $scope.goToPage = (page) ->
        page = Math.max(0, page)
        page = Math.min($scope.numberOfPages - 1, page)

        $scope.currentPage = page

      $scope.update()

      $scope.$watch "list", () ->
        $scope.update()

  }
]