from downloader import *


class MainProcess():
    def __init__(self):
        self.spider = pixiv_spider()
        self.spider.install_dependency()

    def rank_download_event(self):
        number = eval(input('input the number of images you want to download in today\'s ranking list:'))
        # print(type(number))
        while type(number) != int:
            number = eval(input('number must be an integer among [1, 500]:'))
        while number < 1 or number > 500:
            number = eval(input('number must be an integer among [1, 500]:'))
        self.spider.download_ranking_images(num=number)

    def pid_download_event(self):
        pid_str = input('input the pid of the artwork of the image/comic:')
        url, cnt = self.spider.get_download_url(pid_str)
        self.spider.download_image(url, cnt)

    def open_login_window(self):
        # if not self.login_window:
        #     self.login_window = LoginWindow(self)  # Create an instance of LoginWindow if not created yet
        # self.login_window.exec_()  # Show the login window
        return None


if __name__ == '__main__':
    mode = input('Choose mode: {rank list}(r) of {single img}(s):(please input r/s)')
    p = MainProcess()
    while mode != 'r' and mode != 's':
        mode = input('No such mode, retry:(r/s)')
    if mode == 's':
        p.pid_download_event()
    elif mode == 'r':
        p.rank_download_event()
