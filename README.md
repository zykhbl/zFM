# zFM

献给所有的copy cat们，开始新项目了，所以暂时不再测试改bug。。

zFM是一个基于苹果IOS SDK里的两个音频类子项目iPhoneACFileConvertTest ＋ iPhoneMixerEQGraphTest的二次开发，
我只是在解码音频时加入pthread控制好音频流的下载和解码之间的缓冲，在播放时加入一个环结构做播放队列的缓冲。。

DONE:
1.实时播放网络音频流
2.加入Graph Unit均衡器

ps：时间仓促，加上网络环境，音频类型的各种各样，可能会存在一些未知道的bugs。。

UNSUPPORT:
1.不支持微软的WMA格式，因为专利问题，苹果提供的AudioFile SDK不支持WMA格式的音频文件读取
2.无损的PCM格式音频在转码时可能会出错，应该只需要调整一下AudioConverterFillComplexBuffer就可以，即使这样不能解决，因为根本上PCM格式的音频就不需要转码，所以还有其他的解决方案


TODO:
1.在弱网时，加入指数规避算法，控制好下载缓存
2.断点续传，多点下载
3.录音，多音轨混音，实时转码
4.混响器
5.MIDI？
6.人声消除？
7.网络电话？
