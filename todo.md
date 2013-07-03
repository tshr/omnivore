##Probably Good Ideas

* d3 / angular visualization of feed request patterns
* feed domain level counts
* find better place to initialize redis client
* figure out stubbing so it can be done directly on redis client instead of Redis.any_instance

##Lower Priority / Possibly Bad Ideas

* go through Google Reader API and see if there's features that sound like they'd be good to add
* feed reformatting
* performance testing
* duplicate content checking using hashing
* authentication
* threading or multiple processes
* access individual items in feeds
* cleaner way of checking if redis instance is running and abort app if not