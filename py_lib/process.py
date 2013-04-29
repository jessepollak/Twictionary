import re
import time
import string
from pymongo import MongoClient
from nltk.tokenize.treebank import TreebankWordTokenizer

connection = MongoClient('localhost', 27017)

db = connection.twictionary


class TwitterTokenizer(TreebankWordTokenizer):

    def tokenize(self, text):
        #starting quotes
        text = re.sub(r'^\"', r'``', text)
        text = re.sub(r'(``)', r' \1 ', text)
        text = re.sub(r'([ (\[{<])"', r'\1 `` ', text)

        #punctuation
        text = re.sub(r'([:,])([^\d])', r' \1 \2', text)
        text = re.sub(r'\.\.\.', r' ... ', text)
        text = re.sub(r'[;#%&]', r' \g<0> ', text)
        text = re.sub(r'([^\.])(\.)([\]\)}>"\']*)\s*$', r'\1 \2\3 ', text)
        text = re.sub(r'[?!]', r' \g<0> ', text)
        text = re.sub(r'@([A-Za-z0-9_]+)', 'yaboijaquan', text)

        text = re.sub(r"([^'])' ", r"\1 ' ", text)

        #parens, brackets, etc.
        text = re.sub(r'[\]\[\(\)\{\}\<\>]', r' \g<0> ', text)
        text = re.sub(r'--', r' -- ', text)

        #add extra space to make things easier
        text = " " + text + " "

        #ending quotes
        text = re.sub(r'"', " '' ", text)
        text = re.sub(r'(\S)(\'\')', r'\1 \2 ', text)

        text = re.sub(r"([^' ])('[sS]|'[mM]|'[dD]|') ", r"\1 \2 ", text)
        text = re.sub(r"([^' ])('ll|'re|'ve|n't|) ", r"\1 \2 ", text)
        text = re.sub(r"([^' ])('LL|'RE|'VE|N'T|) ", r"\1 \2 ", text)

        # Ignore contractions because we are looking for more meaning
        # for regexp in self.CONTRACTIONS2:
        #     text = regexp.sub(r' \1 \2 ', text)
        # for regexp in self.CONTRACTIONS3:
        #     text = regexp.sub(r' \1 \2 ', text)

        text = re.sub(" +", " ", text)
        text = text.strip()

        #add space at end to match up with MacIntyre's output (for debugging)
        if text != "":
            text += " "

        return text.split()


class Pairer(object):

    def __init__(self, num_tweets=False, debug=False, time=False):

        self.collection = db.twictionary_models_tweets
        self.tres = db.twictionary_models_tres

        opts = dict(fields=dict(date=0, _id=0, tid=0, user=0))
        if num_tweets:
            opts['limit'] = num_tweets

        if debug or time:
            opts['limit'] = 5000

        self.tweets = self.collection.find(**opts)
        self.persister = Persister(debug=debug)
        self.punctuation = set(string.punctuation)
        self.debug = debug
        self.time = time
        self.tokenizer = TwitterTokenizer()

        self.run()

    def run(self):
        if self.time:
            start_time = time.time()

        for t in self.tweets:
            self.pair(t)

        if self.time:
            end_time = time.time()
            print "Run time: %s" % (end_time - start_time)
            self.tres.remove({})

    def pair(self, tweet):
        text = tweet['text']
        tokenized = self.tokenizer.tokenize(text)
        length = len(tokenized)
        for i in range(length):
            token = tokenized[i]
            if not self.is_bad_token(token):
                previous = None
                next = None
                if i != 0:
                    previous = tokenized[i-1]
                    if self.is_bad_token(previous):
                        previous = None

                if i < (length - 1):
                    next = tokenized[i+1]
                    if self.is_bad_token(next):
                        next = None

                self.persister.add(main=token, previous=previous, next=next)

    def is_punctuation(self, token):
        return token in self.punctuation

    def is_bad_token(self, token):
        return self.is_link(token) or self.is_punctuation(token)

    def is_link(self, token):
        return token == u'http' \
            or token == u'https' \
            or token[0:2] == "//"


class Persister(object):

    def __init__(self, debug=False):
        self.unpersisted = []
        self.count = 0
        self.total = 0
        self.collection = db.twictionary_models_tres
        self.debug = debug
        self.insert_cap = 3000

    def add(self, main=None, previous=None, next=None):
        doc = {
            "word": main,
            "previous": previous,
            "next": next
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
        self.unpersisted = []
        self.count = 0


