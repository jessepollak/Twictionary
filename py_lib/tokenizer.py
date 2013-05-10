import re
import string
import unicodedata
from nltk.tokenize.treebank import TreebankWordTokenizer


class TwitterTokenizer(TreebankWordTokenizer):

    PUNCTUATION = set(string.punctuation)

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

        # text = re.sub(r"([^' ])('[sS]|'[mM]|'[dD]|') ", r"\1 \2 ", text)
        # text = re.sub(r"([^' ])('ll|'re|'ve|n't|) ", r"\1 \2 ", text)
        # text = re.sub(r"([^' ])('LL|'RE|'VE|N'T|) ", r"\1 \2 ", text)

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

    def is_punctuation(self, token):
        for i in token:
            if i in self.PUNCTUATION or \
                    unicodedata.category(i)[0] == 'P':
                return True

        return False

    def is_bad_token(self, token):
        return self.is_link(token) or self.is_punctuation(token)

    def is_link(self, token):
        return token == u'http' \
            or token == u'https' \
            or token[0:2] == "//"
