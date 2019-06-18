# SlidingWindow
Data loading in a sliding window fashion. Specifically for using with raw SQLite databases.

## Problem
SQLite is attractive. Core Data is there, Realm is there. But using raw SQLite still has its charm.
However, other than persistence, SQLite doesn't help you in how you manage data you copied to use in your app.
So, for really long lists of data, you have to engineer how you're going to have that data loaded fast and without hogging memory.

## Idea
Solution: Pagination. However, its simple (and popular) form of it is still problematic.
It goes like this, fetch your data "page by page" using `LIMIT <skip>, <count>`, and **append every page to an array**. Obviously this is not memory-efficient because that array keeps growing. We want to only keep a few pages in memory, while those who are far away can have their memory reclaimed.
**This is the essence of a sliding window data loading technique**.

So, this how things work in general:
1. First, you have to provide all the ids of the records beforehand. This should not use much memory, and also should be much quicker since there's no copying being done.
2. Initialize the window with the ids, window size (optional), and a closure to provide record data corresponding to ids of the requested window.
3. Now the window begins using the provided closure to fetch items of the current window. This is done as soon as the first item in the said window is requested.
Of course this is done asynchronously. However, you can optionally block the current thread till the data is ready. This may be useful for table views with self sizing cells that depends on the expected data. See the example.
4. When the data of the current window is fetched, it's then put in a memory cache. This cache is configurable to retain a number of windows. It gets rid of items in pages further than the current page with a configurable threshold.
5. A callback can optionally be called to reload data upon it becoming ready.

See example project for usage.

