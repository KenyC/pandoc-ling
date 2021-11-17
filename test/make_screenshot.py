import argparse
import os.path
from selenium import webdriver

parser = argparse.ArgumentParser(
	description = """
Makes browser screenshot using Selenium.
""")
parser.add_argument(
	"input", metavar = 'input',  
	type = str, help = 'Input file'
)
parser.add_argument(
	"output", metavar = 'output',  
	type = str, help = 'Output file'
)
args = parser.parse_args()

input_file  = os.path.abspath(args.input)
output_file = os.path.abspath(args.output)
# print(os.path.abspath(args.input))
# print(os.path.abspath(args.output))

browser = webdriver.Firefox()
browser.get("file:///{}".format(input_file))
browser.maximize_window()
success = browser.save_screenshot(output_file)
browser.quit()
if not success:
	raise Exception("Could not save screenshot to {} !".format(output_file))