from codecs import StreamReader
import logging

import azure.functions as func


def main(inputblob: func.InputStream, outputBlob: func.Out[func.InputStream]):
    logging.info(f"Python blob trigger function processed blob \n"
                 f"Name: {inputblob.name}\n"
                 f"Blob Size: {inputblob.length} bytes")
    logging.info(f"{inputblob.name} started copying...!")
    outputBlob.set(inputblob)
    logging.info(f"File is successfully copied...!")