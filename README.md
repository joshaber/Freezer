# Freezer

Freezer is inspired by / ripped off from Rich Hickey's talk, [The Database as a Value](http://www.infoq.com/presentations/Datomic-Database-Value) and [Datomic](http://www.datomic.com).

Freezer is an **immutable value store**. All changes to the store create a new 
database, as opposed to changing the database in place. Once you have pulled a
database out of the store, it never changes. It is a fixed view of the store at 
that point in time.

Freezer is made up of a few basic components:

* `FRZStore` is the top-level _thing_. The store is where you go to get the 
current database or get a transactor to perform changes.
* `FRZDatabase` is how you get data out of the store. It is immutable. It never 
changes in place.
* `FRZTransactor` is responsible for adding or removing values from the store.

## Attributes

Freezer does not store objects. Instead, it stores an arbitrary collection of 
attribute-value pairs, grouped by a key. Attributes have a fixed type and must
be added to the store before being used. (See `-[FRZStore addAttribute:type:error:]`.)

A collection of attributes, grouped by key, may be transformed into, for example,
a [Mantle](https://github.com/github/Mantle) model object. But note that model 
object is simply a view on the data. It is not the thing itself.

## Changes

Stores provide a `RACSignal` of changes which are applied to the store. This 
signal can be filtered, throttled, etc. as needed to find out about the changes
your app cares about.

## Thread-safety

Freezer is completely thread-safe. Databases may be read from in any thread and 
`FRZTransactor` may add or remove values in any thread.

## If the database is immutable... does that mean the store grows without bound?

[Yuuuuuuuuuup](http://www.youtube.com/watch?v=zu9ZxzsWchg). That's less than 
ideal.

## Should I use this?

[Nooooooooope](http://www.youtube.com/watch?v=mJXYMDu6dpY). Or at least not yet. 
Freezer's still in a constant state of flux. Also, the above thing about the 
store growing without bound.
