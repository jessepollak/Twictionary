import enchant
from pymongo import MongoClient
from collections import Counter
from tokenizer import TwitterTokenizer


connection = MongoClient('localhost', 27017)

db = connection.twictionary


class DefinitionTokenizer(TwitterTokenizer):

    def __init__(self):
        super(DefinitionTokenizer, self).__init__()
        self.dictionary = enchant.Dict("en")

    def is_defined_token(self, x):
        return super(DefinitionTokenizer, self).is_bad_token(x) \
            or x[0].isupper() \
            or x.isdigit() \
            or self.dictionary.check(x) \
            or self.contains_bad_token(x) \
            or x == "yaboijaquan"

    def contains_bad_token(self, x):
        for i in x:
            if self.is_punctuation(x) \
                    or i.isdigit()  \
                    or i.isupper():
                return True

        return False


class Definer(object):

    def __init__(self):
        self.tres = db.twictionary_models_tres
        self.tweets = db.twictionary_models_tweets
        self.tokenizer = DefinitionTokenizer()
        self.undefined = 0
        self.defined = 0
        self.total = 0
        self.run()

    def run(self):
        tweets = self.tweets.find(limit=5000)
        need_definition = []
        found_similars = dict()
        correct = 0

        for tweet in tweets:

            tokens = self.tokenizer.tokenize(tweet['text'])
            length = len(tokens)
            for i in range(length):
                x = tokens[i]
                if not self.tokenizer.is_defined_token(x):
                    need_definition.append(x)

        for undefined in set(need_definition):
            if self.total % 100 == 0:
                print "{}/{}".format(self.total, len(need_definition))
            similars = self.similarity(undefined)
            valid_similars = []
            total = 0.0
            for similar, score in similars:
                total += score

            for similar, score in similars:
                if not self.tokenizer.contains_bad_token(similar):
                    if similar == 'yaboijaquan':
                        similar = "@mention"
                    valid_similars.append(similar)

            found_similars[undefined] = valid_similars

        print found_similars
        for undefined in found_similars:
            print unicode("{}: {}").format(undefined, " ".join(found_similars[undefined]))
            print "Is this correct? yn"
            resp = raw_input()
            if resp == "y":
                correct += 1



        print "=" * 80
        print "Number of words processed: {}".format(self.total)
        print "Number of words defined: {}".format(self.defined)
        print "Number of words correctly defined: {}".format(correct)
        print "Percent of words accurately defined: {}".format(correct / float(self.defined))
        print "Definition percentage: {:.2}%".format(float(self.defined) / self.total)

    def similarity(self, token):
        uses = self.tres.find({'word': token})
        counter = Counter()
        checked = dict()
        for use in uses:
            previous = use['previous']
            next = use['next']

            if not (previous is None or next is None):
                if not checked.get((previous, next), False):
                    similars = self.tres.find({'previous': previous, 'next': next})
                    for sim in similars:
                        counter[sim['word']] += 1

                    checked[(previous, next)] = True

        if len(checked) == 0:
            self.undefined += 1
        else:
            self.defined += 1

        self.total += 1

        return counter.most_common(10)

d = Definer()
