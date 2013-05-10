import time
import string
from pymongo import MongoClient
from tokenizer import TwitterTokenizer

connection = MongoClient('localhost', 27017)

db = connection.twictionary


class Pairer(object):

    def __init__(self, num_tweets=False, debug=False, time=False):

        self.collection = db.twictionary_models_tweets
        self.tres = db.twictionary_models_tres

        opts = dict(fields=dict(date=0, tid=0, user=0), timeout=False)
        if num_tweets:
            opts['limit'] = num_tweets

        if debug or time:
            opts['limit'] = 5000

        self.tweets = self.collection.find(**opts)
        self.persister = Persister(debug=debug)
        self.debug = debug
        self.time = time
        self.tokenizer = TwitterTokenizer()

        self.run()

    def run(self):
        total = 0
        start_time = time.time()
        end_time = time.time()
        if self.time:
            start_time = time.time()

        for t in self.tweets:
            if total % 100000 == 0:
                end_time = time.time()
                print "processed %s documents!" % total
                print "these documents took %s seconds to process" % (end_time - start_time)
                start_time = time.time()

            self.pair(t)
            total += 1

        if self.time:
            end_time = time.time()
            print "Run time: %s" % (end_time - start_time)
            self.tres.remove({})

    def pair(self, tweet):
        text = tweet['text']
        id = tweet['_id']
        tokenized = self.tokenizer.tokenize(text)
        length = len(tokenized)
        for i in range(length):
            token = tokenized[i]
            if not self.tokenizer.is_bad_token(token):
                previous = None
                next = None
                if i != 0:
                    previous = tokenized[i-1]
                    if self.tokenizer.is_bad_token(previous):
                        previous = None

                if i < (length - 1):
                    next = tokenized[i+1]
                    if self.tokenizer.is_bad_token(next):
                        next = None

                self.persister.add(main=token, previous=previous, next=next, id=id)


class Persister(object):

    def __init__(self, debug=False):
        self.unpersisted = []
        self.count = 0
        self.total = 0
        self.collection = db.twictionary_models_tres
        self.debug = debug
        self.insert_cap = 3000

    def add(self, main=None, previous=None, next=None, id=id):
        doc = {
            "word": main,
            "previous": previous,
            "next": next,
            "tweet_id": id
        }
        self.unpersisted.append(doc)
        self.count += 1
        if self.count == self.insert_cap:
            self.persist()

    def persist(self):
        if not self.debug:
            self.collection.insert(self.unpersisted)
        else:
            print "Insert %s" % self.count
        self.total += self.insert_cap
        self.unpersisted = []
        self.count = 0

p = Pairer()
