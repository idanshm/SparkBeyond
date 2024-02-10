import os
import random
import string
from collections import Counter
from typing import List
from fastapi import FastAPI


app = FastAPI()


def process_article(file_path: str) -> List[str]:
    with open(file_path, 'r', encoding='utf-8') as file:
        text = file.read()
        words = text.split()
        words = [word.strip(string.punctuation).lower() for word in words]
        stopwords = {'the', 'and', 'of', 'in', 'to', 'a', 'is', 'it', 'that', 'as', 'for'}
        words = [word for word in words if word not in stopwords]
        word_counts = Counter(words)
        most_common_words = word_counts.most_common(10)
        return [word for word, _ in most_common_words]


@app.get("/process_articles")
def process_articles():
    article_folder = "./articles"
    articles = os.listdir(article_folder)
    selected_articles = random.sample(articles, k=4)
    common_words_per_article = {}
    for article in selected_articles:
        file_path = os.path.join(article_folder, article)
        common_words = process_article(file_path)
        common_words_per_article[article] = common_words
    return common_words_per_article


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
