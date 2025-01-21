from loguru import logger
from tqdm import tqdm
from zenml import get_step_context, step

from second_brain.application.crawlers import Crawl4AICrawler
from second_brain.domain import Document


@step
def crawl(documents: list[Document], max_workers: int = 10) -> list[Document]:
    """Crawl pages and their child URLs.

    Args:
        documents: List of documents to crawl and extract child URLs from.
        max_workers: Maximum number of concurrent requests. Defaults to 10.

    Returns:
        list[Document]: List containing original documents plus newly crawled child documents.
    """

    crawler = Crawl4AICrawler(max_concurrent_requests=max_workers)
    augmented_pages = documents.copy()

    for page in tqdm(documents, desc="Crawling child URLs of given documents."):
        child_pages = crawler(page)
        augmented_pages.extend(child_pages)

    augmented_pages = list(set(augmented_pages))

    logger.info(f"Before crawling, we had {len(documents)} documents.")
    logger.info(f"After crawling, we have a total of {len(augmented_pages)} documents.")
    logger.info(
        f"After crawling, we have {len(augmented_pages) - len(documents)} new documents."
    )

    step_context = get_step_context()
    step_context.add_output_metadata(
        output_name="crawled_documents",
        metadata={
            "len_documents_before_crawling": len(documents),
            "len_documents_after_crawling": len(augmented_pages),
            "len_documents_new": len(augmented_pages) - len(documents),
        },
    )

    return augmented_pages
