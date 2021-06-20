# Data Warehouse Work Sample Solution Chris Geno (chris@chrisgeno.net)

### <a id="toc-table-of-contents"></a> Table of Contents:
------
- [Introduction](#toc-introduction)
- [Assumptions](#toc-assumptions)
- [Initial Basic Measures We Want to Track and their schema](#toc-initial-solution)
- [A Step Further](#toc-a-step-further)
- [ETL and Infrastructure](#toc-etl-infrastructure)
- [Testing and Debugging](#toc-testing-and-debugging)

[^back](#toc-table-of-contents)

### <a id="toc-introduction"></a>Introduction:

When considering a data selection problem with an already perfectly structured 2NF schema, my initial thought is to simply denormalize the data at the highest resolution required and provide a basic reporting table. However, taking into account that "we often want to slice and dice these measurements" and we have a variety of types of analysts working with it with varied levels of query skill and tools, a partially denormalized schema that stands up to more performance scrutiny or "weird" tool generated queries is what I'll create in this instance.

[^back](#toc-table-of-contents)

### <a id="toc-assumptions"></a> Assumptions:

* The data in the existing schema is already well formed. IE: dates aren't at impossible times in the future, people aren't a million years old. Essentially I won't check for outlier values with constraints that would obliterate statistics. 
* Users will have varying levels of skill and toolsets to access this data. IE: I will attempt to optimize for toosl like Tableau auto generating weird queries with suboptimal subqueries.
* For simplification, I'll also assume we aren't doing analysis on the app's use itself. IE: the relationship between when a particular object is updated is less important than the actual statistics and dimensions generated through driving activities. 
* 

[^back](#toc-table-of-contents)

### <a id="toc-initial-solution"></a> Initial Basic Measures We Want to Track and a schema, (The oversimplified single query solution we don't want):

Even though this is not what we want. Quickly creating the query that provides the basic structure of the measurements asked for is something I like to do to setup a basic structure to think about. So I'll put that here and then build off of it.

```sql:most_basic.sql
```


[^back](#toc-table-of-contents)

### <a id="toc-a-step-further"></a> A Step Further:

### <a id="toc-etl-infrastructure"></a> ETL and Infrastructure:

### <a id="toc-testing-and-debugging"></a> Testing and Debugging:

