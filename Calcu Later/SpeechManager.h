#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 共用的中文語音朗讀（TTS）。封裝 AVSpeechSynthesizer 與「最佳中文嗓音」挑選，
/// 並可在朗讀過程回報「即將朗讀的字元範圍」，供呼叫端做 karaoke 逐字高亮。
///
/// 設計為單例（與 SoundManager 對齊）：整個 app 共用一顆合成器，
/// 任何一次新的 speak 會自動中斷前一段朗讀。
@interface SpeechManager : NSObject

@property (class, nonatomic, readonly) SpeechManager *sharedInstance;

/// 朗讀一段文字（兒童友善語速）。會先停止前一段朗讀。
- (void)speak:(NSString *)text;

/// 朗讀並回報進度，供逐字高亮使用。
/// @param willSpeakRange 每次即將朗讀某段字元時於主執行緒呼叫，帶入該段在 text 中的 NSRange。
/// @param onFinish 朗讀完成或被中斷時於主執行緒呼叫一次（用來清除高亮）。
- (void)speak:(NSString *)text
    willSpeakRange:(nullable void (^)(NSRange characterRange))willSpeakRange
          onFinish:(nullable void (^)(void))onFinish;

/// 停止目前朗讀（會觸發當前 onFinish 以便呼叫端清除高亮）。
- (void)stop;

@end

NS_ASSUME_NONNULL_END
