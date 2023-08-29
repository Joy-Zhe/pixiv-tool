import os
import zipfile
import requests
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
import pickle


class pixiv_spider:
    def __init__(self, username='youremail@mail.com', password='your_password'):
        self.login_status = False
        self.cookies = {}
        self.username = username
        self.password = password
        self.max_rank = 1
        if not os.path.exists('./images'):
            os.mkdir('./images')
        self.cookie_status = os.path.exists('./cookies.pkl')
        self.headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0Safari/537.36 Edg/115.0.1901.200',
            'Referer': 'https://www.pixiv.net/',
        }

    def install_dependency(self, platform='win32'):  # platforms：win32、mac64、linux64
        chrome_version = "92.0.4515.43"
        download_url = f"https://chromedriver.storage.googleapis.com/{chrome_version}/chromedriver_{platform}.zip"
        # print(download_url)
        driver_path = './chromedriver/'
        chrome_driver_path = driver_path + 'chromedriver.exe'
        # print(chrome_driver_path)
        if not os.path.exists(chrome_driver_path):
            # download zipfile
            response = requests.get(download_url)
            with open("chromedriver.zip", "wb") as zip_file:
                zip_file.write(response.content)
            # extract zipfile
            with zipfile.ZipFile("chromedriver.zip", "r") as zip_ref:
                zip_ref.extractall(driver_path)

            # delete zipfile
            os.remove("chromedriver.zip")

            # print("chromedriver saved")
        else:
            print('Chromedriver already satisfied.')
        # download browserMob-proxy
        # browser_mob_url = 'https://github.com/lightbody/browsermob-proxy/releases/download/browsermob-proxy-2.1.4' \
        #                   '/browsermob-proxy-2.1.4-bin.zip'
        # mob_proxy_path = './browsermob_proxy/'
        # browser_mob_path = mob_proxy_path + 'browsermob-proxy-2.1.4/bin/browsermob-proxy.bat'
        # if not os.path.exists(browser_mob_path):
        #     # download zipfile
        #     response1 = requests.get(browser_mob_url)
        #     with open("browsermob-proxy-2.1.4-bin.zip", "wb") as zip_file:
        #         zip_file.write(response1.content)
        #     # extract zipfile
        #     with zipfile.ZipFile("browsermob-proxy-2.1.4-bin.zip", "r") as zip_ref:
        #         zip_ref.extractall(mob_proxy_path)
        #
        #     # delete zipfile
        #     os.remove("browsermob-proxy-2.1.4-bin.zip")
        #
        #     # print("chromedriver saved")
        # else:
        #     print('browsermobproxy already satisfied.')
        # download successfully

    def login(self):
        if self.cookie_status:
            # self.rouse_browser()
            print('cookies already exists, no need to login again.')
            with open('./cookies.pkl', 'rb') as fp:
                self.cookies = pickle.load(fp)
        else:
            self.rouse_browser()

    def rouse_browser(self):
        # server = Server('D:/code/pixiv-spider/browsermob_proxy/browsermob-proxy-2.1.4/bin/browsermob-proxy.bat')
        # server.start()
        # proxy = server.create_proxy()

        options = webdriver.ChromeOptions()
        options.add_argument('--ignore-certification-errors')
        options.add_experimental_option('excludeSwitches', ['enable-automation'])
        options.add_argument('--disable-blink-features=AutomationControlled')
        # options.add_argument('--proxy-server={0}'.format(proxy.proxy))
        options.add_argument('--headless')  # hide the window
        browser = webdriver.Chrome(options=options)

        # proxy.new_har('pixiv')

        login_url = 'https://www.pixiv.net/login.php'
        browser.get(login_url)
        wait = WebDriverWait(browser, 10)
        username_input = browser.find_element(By.CSS_SELECTOR, 'input[placeholder="邮箱地址或pixiv ID"]')
        password_input = browser.find_element(By.CSS_SELECTOR, 'input[placeholder="密码"]')
        username_input.send_keys(self.username)
        password_input.send_keys(self.password)

        # har = proxy.har

        login_button = browser.find_element(By.CSS_SELECTOR, 'button[type="submit"]')
        login_button.click()

        # for entry in har['log']['entries']:
        #     request = entry['request']
        #     response = entry['response']
        #     request_headers = request['headers']
        #     response_headers = response['headers']
        #
        #     for header in request_headers:
        #         if header['name'] == 'Cookie':
        #             print('Request Cookie:', header['value'])
        #     for header in response_headers:
        #         if header['name'] == 'Cookie':
        #             print('Response Cookie:', header['value'])

        # get and save cookies
        cookies_raw = browser.get_cookies()
        print(cookies_raw)
        # time.sleep(50)
        browser.close()
        # proxy.close()
        # server.stop()
        for cookie in cookies_raw:
            for item in cookie.items():
                self.cookies[str(item[0])] = str(item[1])
        self.cookies[self.cookies['name']] = self.cookies['value']
        del self.cookies['name']
        del self.cookies['value']
        print(self.cookies)
        with open('./cookies.pkl', 'wb') as fp:
            pickle.dump(self.cookies, fp)
        print('cookies saved!')

    def get_download_url(self, pid):
        base_url = 'https://www.pixiv.net/ajax/illust/'
        page_count = 0
        url = base_url + str(pid)
        # print(url)  # for debug
        response = requests.get(url=url, headers=self.headers)
        # print(url)
        # with open('./test_pages/get_original_url_' + str(pid) + '.json', 'w+', encoding='utf-8') as fp:
        #     fp.write(response.text)
        # print('get the information of image' + str(pid))
        img_info = response.json()
        download_url = img_info['body']['urls']['original']
        page_count = img_info['body']['userIllusts'][str(pid)]['pageCount']
        # print(download_url)
        # print(page_count)
        return download_url, page_count

    def download_image(self, url, page_count=1):
        # print(url)
        if url == None:
            url = 'https://i.pximg.net/img-original/img/2023/04/07/10/22/57/106942074_p0.jpg'
            page_count = 1
        filename = url.split('/')[-1]
        base_url = '/'.join(url.split('/')[:-1])
        filetype = filename.split('.')[-1]
        pid = filename.split('.')[-2].split('_')[-2]
        for page_number in range(0, page_count):
            new_url = base_url + f'/{pid}_p{page_number}.{filetype}'
            response = requests.get(url=new_url, headers=self.headers)
            if not os.path.exists(f'./images/{pid}_{page_number}.{filetype}'):
                with open(f'./images/{pid}_{page_number}.{filetype}', 'wb') as fp:
                    fp.write(response.content)
            # print(f'image {pid} PAGE:{page_number + 1}/{page_count} saved!')


    def get_ranking_info(self):
        ranking_json = {}
        response_list = []
        pids = []
        for i in range(1, 11):
            ranking_json[i] = f'https://www.pixiv.net/ranking.php?mode=weekly&p={i}&format=json'
            response_tmp = requests.get(ranking_json[i], headers=self.headers)
            # if not os.path.exists('./ranking_list'):
            #     os.mkdir('./ranking_list')
            # with open(f'./ranking_list/rankinglist{i}.json', 'w+', encoding='utf-8') as fp:
            #     fp.write(response_tmp.text)
            response_list.append(response_tmp)
            info = response_tmp.json()
            for j in range(0, len(info['contents'])):
                pid = info['contents'][j]['illust_id']
                # print(pid)
                pids.append(pid)
        # print(len(pids))
        self.max_rank = len(pids)
        return pids

    def download_ranking_images(self, num=498):
        pids = self.get_ranking_info()
        i = 0
        for pid in pids:
            i += 1
            # print(i)
            url, cnt = self.get_download_url(pid)
            # print(pid)
            self.download_image(url=url, page_count=cnt)
            if i==num:
                break


# username = 'youremail@mail.com'
# password = 'your_password'
# spider = pixiv_spider(username, password)
# # platform = input('Choose platform:(win32/mac64/linux64)')
# # spider.install_dependency(platform=platform)
# spider.install_dependency()
# if not spider.cookie_status:  # no cookies yet(have not logged in before)
#     spider.username = input('input your pixiv id:')
#     spider.password = input('input your password:')
# spider.login()
# # print(spider.cookies)
#
# spider.download_ranking_images()
# test_url, page_cnt = spider.get_download_url('106942074')
# print(f'{test_url} {page_cnt}')
# spider.download_ranking_images(2)