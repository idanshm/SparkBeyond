import os
import subprocess
import random
import string
from collections import Counter
from typing import List
from fastapi import FastAPI
from prometheus_fastapi_instrumentator import Instrumentator

app = FastAPI()
Instrumentator().instrument(app).expose(app)


def process_article(file_path: str) -> List[str]:
    with open(file_path, 'r', encoding='utf-8') as file:
        text = file.read()
        words = text.split()
        words = [word.strip(string.punctuation).lower() for word in words]
        stopwords = {'the', 'and', 'of', 'in', 'to', 'a', 'is', 'it', 'that', 'as', 'for'}  # Ignore/filter stopwords
        words = [word for word in words if word not in stopwords]
        word_counts = Counter(words)
        most_common_words = word_counts.most_common(10)
        return [word for word, _ in most_common_words]


def is_text_file(file_path):
    try:
        output = subprocess.check_output(['file', '--mime', '--brief', file_path])
        return output.decode().split(';')[0].strip() == 'text/plain'
    except subprocess.CalledProcessError:
        return False


def get_text_files_in_folder(folder_path):
    return [file for file in os.listdir(folder_path) if is_text_file(os.path.join(folder_path, file))]


@app.get("/")
async def process_articles():
    article_folder = "./articles"
    articles = get_text_files_in_folder(article_folder)
    if len(articles) < 4:
        return "You need to have at least 4 articles in the articles folder."
    if articles:
        selected_articles = random.sample(articles, k=4)  # Here I decide to choose 4 random articles from the articles folder on each api call. You can this to a list of static article names instead.
        common_words_per_article = {}
        for article in selected_articles:
            file_path = os.path.join(article_folder, article)
            common_words = process_article(file_path)
            common_words_per_article[article] = common_words
        return common_words_per_article
    else:
        return "Couldn't find any valid articles ):"


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
