import sys
from PyQt5.QtWidgets import QApplication, QMainWindow, QDialog
from downloader import *
from MainWindow import *
from LoginWindow import *

# class LoginWindow(QDialog, Ui_LoginWindow):
#     def __init__(self, parent=None):
#         super(LoginWindow, self).__init__(parent)
#         self.setupUi(self)

class MyWindow(QMainWindow, Ui_MainWindow):
    def __init__(self, parent=None):
        super(MyWindow, self).__init__(parent)
        self.spider = pixiv_spider()
        self.spider.install_dependency()
        self.setupUi(self)
        self.rank_download_button.clicked.connect(self.rank_download_event)
        self.actionLogin_to_Pixiv.triggered.connect(self.open_login_window)
        self.login_window = None  # Initialize login window as None
        self.pid_download.clicked.connect(self.pid_download_event)

    def rank_download_event(self):
        number = self.rank_cnt.toPlainText()
        print(number)
        number = int(number)
        self.rank_cnt.setText('')
        self.spider.download_ranking_images(num=number)

    def pid_download_event(self):
        pid_str = self.pid.toPlainText()
        url, cnt = self.spider.get_download_url(pid_str)
        self.pid.setText('')
        self.spider.download_image(url, cnt)

    def open_login_window(self):
        # if not self.login_window:
        #     self.login_window = LoginWindow(self)  # Create an instance of LoginWindow if not created yet
        # self.login_window.exec_()  # Show the login window
        return None

if __name__ == '__main__':
    app = QApplication(sys.argv)
    myWin = MyWindow()
    myWin.show()
    sys.exit(app.exec_())
