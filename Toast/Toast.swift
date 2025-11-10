//
//  Toast.swift
//  Toast-Swift
//
//  Copyright (c) 2015-2024 Charles Scalesse.
//
//  Permission is hereby granted, free of charge, to any person obtaining a
//  copy of this software and associated documentation files (the
//  "Software"), to deal in the Software without restriction, including
//  without limitation the rights to use, copy, modify, merge, publish,
//  distribute, sublicense, and/or sell copies of the Software, and to
//  permit persons to whom the Software is furnished to do so, subject to
//  the following conditions:
//
//  The above copyright notice and this permission notice shall be included
//  in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
//  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
//  CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
//  TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
//  SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import UIKit
import ObjectiveC

/**
 Toast is a Swift extension that adds toast notifications to the `UIView` object class.
 It is intended to be simple, lightweight, and easy to use. Most toast notifications
 can be triggered with a single line of code.
 
 The `makeToast` methods create a new view and then display it as toast.
 
 The `showToast` methods display any view as toast.
 
 */
public extension UIView {
    
    /**
     Keys used for associated objects.
     */
    private struct ToastKeys {
        static var timer = malloc(1)
        static var duration = malloc(1)
        static var point = malloc(1)
        static var completion = malloc(1)
        static var activeToasts = malloc(1)
        static var activityView = malloc(1)
        static var queue = malloc(1)
    }
    
    /**
     Swift closures can't be directly associated with objects via the
     Objective-C runtime, so the (ugly) solution is to wrap them in a
     class that can be used with associated objects.
     */
    private class ToastCompletionWrapper {
        let completion: ((Bool) -> Void)?
        
        init(_ completion: ((Bool) -> Void)?) {
            self.completion = completion
        }
    }
    
    private enum ToastError: Error {
        case missingParameters
    }
    
    private var activeToasts: NSMutableArray {
        get {
            if let activeToasts = objc_getAssociatedObject(self, &ToastKeys.activeToasts) as? NSMutableArray {
                return activeToasts
            } else {
                let activeToasts = NSMutableArray()
                objc_setAssociatedObject(self, &ToastKeys.activeToasts, activeToasts, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                return activeToasts
            }
        }
    }
    
    private var queue: NSMutableArray {
        get {
            if let queue = objc_getAssociatedObject(self, &ToastKeys.queue) as? NSMutableArray {
                return queue
            } else {
                let queue = NSMutableArray()
                objc_setAssociatedObject(self, &ToastKeys.queue, queue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                return queue
            }
        }
    }
    
    // MARK: - Make Toast Methods
    
    /**
     Creates and presents a new toast view.
     
     @param message The message to be displayed
     @param duration The toast duration
     @param position The toast's position
     @param title The title
     @param image The image
     @param style The style. The shared style will be used when nil
     @param completion The completion closure, executed after the toast view disappears.
     didTap will be `true` if the toast view was dismissed from a tap.
     */
    func makeToast(_ message: String?, duration: TimeInterval = ToastManager.shared.duration, position: ToastPosition = ToastManager.shared.position, title: String? = nil, image: UIImage? = nil, style: ToastStyle = ToastManager.shared.style, completion: ((_ didTap: Bool) -> Void)? = nil) {
        do {
            let toast = try toastViewForMessage(message, title: title, image: image, style: style)
            showToast(toast, duration: duration, position: position, completion: completion)
        } catch ToastError.missingParameters {
            print("Error: message, title, and image are all nil")
        } catch {}
    }
    
    /**
     Creates a new toast view and presents it at a given center point.
     
     @param message The message to be displayed
     @param duration The toast duration
     @param point The toast's center point
     @param title The title
     @param image The image
     @param style The style. The shared style will be used when nil
     @param completion The completion closure, executed after the toast view disappears.
     didTap will be `true` if the toast view was dismissed from a tap.
     */
    func makeToast(_ message: String?, duration: TimeInterval = ToastManager.shared.duration, point: CGPoint, title: String?, image: UIImage?, style: ToastStyle = ToastManager.shared.style, completion: ((_ didTap: Bool) -> Void)?) {
        do {
            let toast = try toastViewForMessage(message, title: title, image: image, style: style)
            showToast(toast, duration: duration, point: point, completion: completion)
        } catch ToastError.missingParameters {
            print("Error: message, title, and image cannot all be nil")
        } catch {}
    }
    
    // MARK: - Show Toast Methods
    
    /**
     Displays any view as toast at a provided position and duration. The completion closure
     executes when the toast view completes. `didTap` will be `true` if the toast view was
     dismissed from a tap.
     
     @param toast The view to be displayed as toast
     @param duration The notification duration
     @param position The toast's position
     @param completion The completion block, executed after the toast view disappears.
     didTap will be `true` if the toast view was dismissed from a tap.
     */
    func showToast(_ toast: UIView, duration: TimeInterval = ToastManager.shared.duration, position: ToastPosition = ToastManager.shared.position, completion: ((_ didTap: Bool) -> Void)? = nil) {
        let point = position.centerPoint(forToast: toast, inSuperview: self)
        showToast(toast, duration: duration, point: point, completion: completion)
    }
    
    /**
     Displays any view as toast at a provided center point and duration. The completion closure
     executes when the toast view completes. `didTap` will be `true` if the toast view was
     dismissed from a tap.
     
     @param toast The view to be displayed as toast
     @param duration The notification duration
     @param point The toast's center point
     @param completion The completion block, executed after the toast view disappears.
     didTap will be `true` if the toast view was dismissed from a tap.
     */
    func showToast(_ toast: UIView, duration: TimeInterval = ToastManager.shared.duration, point: CGPoint, completion: ((_ didTap: Bool) -> Void)? = nil) {
        objc_setAssociatedObject(toast, &ToastKeys.completion, ToastCompletionWrapper(completion), .OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        if ToastManager.shared.isQueueEnabled, activeToasts.count > 0 {
            objc_setAssociatedObject(toast, &ToastKeys.duration, NSNumber(value: duration), .OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(toast, &ToastKeys.point, NSValue(cgPoint: point), .OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            
            queue.add(toast)
        } else {
            showToast(toast, duration: duration, point: point)
        }
    }
    
    // MARK: - Hide Toast Methods
    
    /**
     Hides the active toast. If there are multiple toasts active in a view, this method
     hides the oldest toast (the first of the toasts to have been presented).
     
     @see `hideAllToasts()` to remove all active toasts from a view.
     
     @warning This method has no effect on activity toasts. Use `hideToastActivity` to
     hide activity toasts.
     
     */
    func hideToast() {
        guard let activeToast = activeToasts.firstObject as? UIView else { return }
        hideToast(activeToast)
    }
    
    /**
     Hides an active toast.
     
     @param toast The active toast view to dismiss. Any toast that is currently being displayed
     on the screen is considered active.
     
     @warning this does not clear a toast view that is currently waiting in the queue.
     */
    func hideToast(_ toast: UIView) {
        guard activeToasts.contains(toast) else { return }
        hideToast(toast, fromTap: false)
    }
    
    /**
     Hides all toast views.
     
     @param includeActivity If `true`, toast activity will also be hidden. Default is `false`.
     @param clearQueue If `true`, removes all toast views from the queue. Default is `true`.
     */
    func hideAllToasts(includeActivity: Bool = false, clearQueue: Bool = true) {
        if clearQueue {
            clearToastQueue()
        }
        
        activeToasts.compactMap { $0 as? UIView }
            .forEach { hideToast($0) }
        
        if includeActivity {
            hideToastActivity()
        }
    }
    
    /**
     Removes all toast views from the queue. This has no effect on toast views that are
     active. Use `hideAllToasts(clearQueue:)` to hide the active toasts views and clear
     the queue.
     */
    func clearToastQueue() {
        queue.removeAllObjects()
    }
    
    // MARK: - Activity Methods
    
    /**
     Creates and displays a new toast activity indicator view at a specified position.
     
     @warning Only one toast activity indicator view can be presented per superview. Subsequent
     calls to `makeToastActivity(position:)` will be ignored until `hideToastActivity()` is called.
     
     @warning `makeToastActivity(position:)` works independently of the `showToast` methods. Toast
     activity views can be presented and dismissed while toast views are being displayed.
     `makeToastActivity(position:)` has no effect on the queueing behavior of the `showToast` methods.
     
     @param position The toast's position
     */
    func makeToastActivity(_ position: ToastPosition) {
        // sanity
        guard objc_getAssociatedObject(self, &ToastKeys.activityView) as? UIView == nil else { return }
        
        let toast = createToastActivityView()
        let point = position.centerPoint(forToast: toast, inSuperview: self)
        makeToastActivity(toast, point: point)
    }
    
    /**
     Creates and displays a new toast activity indicator view at a specified position.
     
     @warning Only one toast activity indicator view can be presented per superview. Subsequent
     calls to `makeToastActivity(position:)` will be ignored until `hideToastActivity()` is called.
     
     @warning `makeToastActivity(position:)` works independently of the `showToast` methods. Toast
     activity views can be presented and dismissed while toast views are being displayed.
     `makeToastActivity(position:)` has no effect on the queueing behavior of the `showToast` methods.
     
     @param point The toast's center point
     */
    func makeToastActivity(_ point: CGPoint) {
        // sanity
        guard objc_getAssociatedObject(self, &ToastKeys.activityView) as? UIView == nil else { return }
        
        let toast = createToastActivityView()
        makeToastActivity(toast, point: point)
    }
    
    /**
     Dismisses the active toast activity indicator view.
     */
    func hideToastActivity() {
        if let toast = objc_getAssociatedObject(self, &ToastKeys.activityView) as? UIView {
            UIView.animate(withDuration: ToastManager.shared.style.fadeDuration, delay: 0.0, options: [.curveEaseIn, .beginFromCurrentState], animations: {
                toast.alpha = 0.0
            }) { _ in
                toast.removeFromSuperview()
                objc_setAssociatedObject(self, &ToastKeys.activityView, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /**
     Returns `true` if a toast view or toast activity view is actively being displayed.
     */
    func isShowingToast() -> Bool {
        return activeToasts.count > 0 || objc_getAssociatedObject(self, &ToastKeys.activityView) != nil
    }
    
    // MARK: - Private Activity Methods
    
    private func makeToastActivity(_ toast: UIView, point: CGPoint) {
        toast.alpha = 0.0
        toast.center = point
        
        objc_setAssociatedObject(self, &ToastKeys.activityView, toast, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        self.addSubview(toast)
        
        UIView.animate(withDuration: ToastManager.shared.style.fadeDuration, delay: 0.0, options: .curveEaseOut, animations: {
            toast.alpha = 1.0
        })
    }
    
    private func createToastActivityView() -> UIView {
        let style = ToastManager.shared.style
        
        let activityView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: style.activitySize.width, height: style.activitySize.height))
        activityView.backgroundColor = style.activityBackgroundColor
        activityView.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        activityView.layer.cornerRadius = style.cornerRadius
        
        if style.displayShadow {
            activityView.layer.shadowColor = style.shadowColor.cgColor
            activityView.layer.shadowOpacity = style.shadowOpacity
            activityView.layer.shadowRadius = style.shadowRadius
            activityView.layer.shadowOffset = style.shadowOffset
        }
        
        let activityIndicatorView = UIActivityIndicatorView(style: .whiteLarge)
        activityIndicatorView.center = CGPoint(x: activityView.bounds.size.width / 2.0, y: activityView.bounds.size.height / 2.0)
        activityView.addSubview(activityIndicatorView)
        activityIndicatorView.color = style.activityIndicatorColor
        activityIndicatorView.startAnimating()
        
        return activityView
    }
    
    // MARK: - Private Show/Hide Methods
    
    private func showToast(_ toast: UIView, duration: TimeInterval, point: CGPoint) {
        toast.center = point
        toast.alpha = 0.0
        
        if ToastManager.shared.isTapToDismissEnabled {
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(UIView.handleToastTapped(_:)))
            toast.addGestureRecognizer(recognizer)
            toast.isUserInteractionEnabled = true
            toast.isExclusiveTouch = true
        }
        
        activeToasts.add(toast)
        self.addSubview(toast)
        
        let timer = Timer(timeInterval: duration, target: self, selector: #selector(UIView.toastTimerDidFinish(_:)), userInfo: toast, repeats: false)
        objc_setAssociatedObject(toast, &ToastKeys.timer, timer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        UIView.animate(withDuration: ToastManager.shared.style.fadeDuration, delay: 0.0, options: [.curveEaseOut, .allowUserInteraction], animations: {
            toast.alpha = 1.0
        }) { _ in
            guard let timer = objc_getAssociatedObject(toast, &ToastKeys.timer) as? Timer else { return }
            RunLoop.main.add(timer, forMode: .common)
        }
        
        UIAccessibility.post(notification: .screenChanged, argument: toast)
    }
    
    private func hideToast(_ toast: UIView, fromTap: Bool) {
        if let timer = objc_getAssociatedObject(toast, &ToastKeys.timer) as? Timer {
            timer.invalidate()
        }
        
        UIView.animate(withDuration: 0.3, delay: 0.0, options: [.curveEaseIn, .beginFromCurrentState], animations: {
            toast.alpha = 0.0
        }) { _ in
            toast.removeFromSuperview()
            self.activeToasts.remove(toast)
            
            if let wrapper = objc_getAssociatedObject(toast, &ToastKeys.completion) as? ToastCompletionWrapper, let completion = wrapper.completion {
                completion(fromTap)
            }
            
            if let nextToast = self.queue.firstObject as? UIView, let duration = objc_getAssociatedObject(nextToast, &ToastKeys.duration) as? NSNumber, let point = objc_getAssociatedObject(nextToast, &ToastKeys.point) as? NSValue {
                self.queue.removeObject(at: 0)
                self.showToast(nextToast, duration: duration.doubleValue, point: point.cgPointValue)
            }
        }
    }
    
    // MARK: - Events
    
    @objc
    private func handleToastTapped(_ recognizer: UITapGestureRecognizer) {
        guard let toast = recognizer.view else { return }
        hideToast(toast, fromTap: true)
    }
    
    @objc
    private func toastTimerDidFinish(_ timer: Timer) {
        guard let toast = timer.userInfo as? UIView else { return }
        hideToast(toast)
    }
    
    // MARK: - Toast Construction
    
    /**
     Creates a new toast view with any combination of message, title, and image.
     The look and feel is configured via the style. Unlike the `makeToast` methods,
     this method does not present the toast view automatically. One of the `showToast`
     methods must be used to present the resulting view.
     
     @warning if message, title, and image are all nil, this method will throw
     `ToastError.missingParameters`
     
     @param message The message to be displayed
     @param title The title
     @param image The image
     @param style The style. The shared style will be used when nil
     @throws `ToastError.missingParameters` when message, title, and image are all nil
     @return The newly created toast view
     */
    func toastViewForMessage(_ message: String?, title: String?, image: UIImage?, style: ToastStyle) throws -> UIView {
        guard message != nil || title != nil || image != nil else {
            throw ToastError.missingParameters
        }
        
        var messageLabel: UILabel?
        var titleLabel: UILabel?
        var imageView: UIImageView?
        
        let wrapperView = UIView()
        wrapperView.backgroundColor = style.backgroundColor
        wrapperView.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        wrapperView.layer.cornerRadius = style.cornerRadius
        
        if style.displayShadow {
            wrapperView.layer.shadowColor = style.shadowColor.cgColor
            wrapperView.layer.shadowOpacity = style.shadowOpacity
            wrapperView.layer.shadowRadius = style.shadowRadius
            wrapperView.layer.shadowOffset = style.shadowOffset
        }
        
        if let image = image {
            imageView = UIImageView(image: image)
            imageView?.contentMode = .scaleAspectFit
            imageView?.frame = CGRect(x: style.horizontalPadding, y: style.verticalPadding, width: style.imageSize.width, height: style.imageSize.height)
        }
        
        var imageRect = CGRect.zero
        
        if let imageView = imageView {
            imageRect.origin.x = style.horizontalPadding
            imageRect.origin.y = style.verticalPadding
            imageRect.size.width = imageView.bounds.size.width
            imageRect.size.height = imageView.bounds.size.height
        }

        // 固定文字高度
           let textHeight: CGFloat = 20
        
        // ===== 修改開始：支援多行文字 =====
        if let title = title {
            titleLabel = UILabel()
            titleLabel?.numberOfLines = 0  // 改為 0 支援多行
            titleLabel?.font = style.titleFont
            titleLabel?.textAlignment = style.titleAlignment
            titleLabel?.lineBreakMode = .byWordWrapping  // 使用單詞換行
            titleLabel?.textColor = style.titleColor
            titleLabel?.backgroundColor = UIColor.clear
            titleLabel?.text = title
            
            let maxTitleSize = CGSize(width: (self.bounds.size.width * style.maxWidthPercentage) - imageRect.size.width - (style.horizontalPadding * 2), height: CGFloat.greatestFiniteMagnitude)
            var titleSize = titleLabel?.sizeThatFits(maxTitleSize)
            
            // 設定最小高度為 22
            if let size = titleSize, size.height < 22.0 {
                titleSize = CGSize(width: size.width, height: 22.0)
            }
            
            if let titleSize = titleSize {
                titleLabel?.frame = CGRect(x: 0.0, y: 0.0, width: titleSize.width, height: titleSize.height)
            }
        }
        
        if let message = message {
            messageLabel = UILabel()
            messageLabel?.text = message
            messageLabel?.numberOfLines = 0  // 改為 0 支援多行
            messageLabel?.font = style.messageFont
            messageLabel?.textAlignment = style.messageAlignment
            messageLabel?.lineBreakMode = .byWordWrapping  // 使用單詞換行
            messageLabel?.textColor = style.messageColor
            messageLabel?.backgroundColor = UIColor.clear
            
            let maxMessageSize = CGSize(width: (self.bounds.size.width * style.maxWidthPercentage) - imageRect.size.width - (style.horizontalPadding * 2), height: CGFloat.greatestFiniteMagnitude)
            var messageSize = messageLabel?.sizeThatFits(maxMessageSize)
            
            // 設定最小高度為 22
            if let size = messageSize, size.height < 22.0 {
                messageSize = CGSize(width: size.width, height: 22.0)
            }
            
            if let messageSize = messageSize {
                messageLabel?.frame = CGRect(x: 0.0, y: 0.0, width: messageSize.width, height: messageSize.height)
            }
        }
        // ===== 修改結束 =====

        var titleRect = CGRect.zero
        
        if let titleLabel = titleLabel {
            titleRect.origin.x = imageRect.origin.x + imageRect.size.width + style.horizontalPadding
            titleRect.origin.y = style.verticalPadding
            titleRect.size.width = titleLabel.bounds.size.width
            titleRect.size.height = titleLabel.bounds.size.height
        }
        
        var messageRect = CGRect.zero
        
        if let messageLabel = messageLabel {
            messageRect.origin.x = imageRect.origin.x + imageRect.size.width + style.horizontalPadding
            messageRect.origin.y = titleRect.origin.y + titleRect.size.height + style.verticalPadding
            messageRect.size.width = messageLabel.bounds.size.width
            messageRect.size.height = messageLabel.bounds.size.height
        }
        
        let longerWidth = max(titleRect.size.width, messageRect.size.width)
        let longerX = max(titleRect.origin.x, messageRect.origin.x)
        let wrapperWidth = max((imageRect.size.width + (style.horizontalPadding * 2.0)), (longerX + longerWidth + style.horizontalPadding))
        
        let textMaxY = messageRect.size.height <= 0.0 && titleRect.size.height > 0.0 ? titleRect.maxY : messageRect.maxY
        let wrapperHeight = max((textMaxY + style.verticalPadding), (imageRect.size.height + (style.verticalPadding * 2.0)))
        
        wrapperView.frame = CGRect(x: 0.0, y: 0.0, width: wrapperWidth, height: wrapperHeight)
        
        if let titleLabel = titleLabel {
            titleRect.size.width = longerWidth
            titleLabel.frame = titleRect
            wrapperView.addSubview(titleLabel)
        }
        
        if let messageLabel = messageLabel {
            messageRect.size.width = longerWidth
            messageLabel.frame = messageRect
            wrapperView.addSubview(messageLabel)
        }
        
        if let imageView = imageView {
            wrapperView.addSubview(imageView)
        }
        
        return wrapperView
    }
}

// MARK: - Toast Style

/**
 `ToastStyle` instances define the look and feel for toast views created via the
 `makeToast` methods as well for toast views created directly with
 `toastViewForMessage(message:title:image:style:)`.
 
 @warning `ToastStyle` offers relatively simple styling options for the default
 toast view. If you require a toast view with more complex UI, it probably makes more
 sense to create your own custom UIView subclass and present it with the `showToast`
 methods.
 */
public struct ToastStyle {
    
    public init() {}
    
    /**
     The background color. Default is `#233440` at 80% opacity.
     */
    public var backgroundColor: UIColor = UIColor(red: 36/255, green: 52/255, blue: 64/255, alpha: 0.8)
    
    /**
     The title color. Default is `UIColor.whiteColor()`.
     */
    public var titleColor: UIColor = .white
    
    /**
     The message color. Default is `.white`.
     */
    public var messageColor: UIColor = .white
    
    /**
     A percentage value from 0.0 to 1.0, representing the maximum width of the toast
     view relative to it's superview. Default is 0.8 (80% of the superview's width).
     */
    public var maxWidthPercentage: CGFloat = 0.8 {
        didSet {
            maxWidthPercentage = max(min(maxWidthPercentage, 1.0), 0.0)
        }
    }
    
    /**
     A percentage value from 0.0 to 1.0, representing the maximum height of the toast
     view relative to it's superview. Default is 0.8 (80% of the superview's height).
     */
    public var maxHeightPercentage: CGFloat = 0.8 {
        didSet {
            maxHeightPercentage = max(min(maxHeightPercentage, 1.0), 0.0)
        }
    }
    
    /**
     The spacing from the horizontal edge of the toast view to the content. When an image
     is present, this is also used as the padding between the image and the text.
     Default is 10.0.
     
     */
    public var horizontalPadding: CGFloat = 16.0
    
    /**
     The spacing from the vertical edge of the toast view to the content. When a title
     is present, this is also used as the padding between the title and the message.
     Default is 10.0. On iOS11+, this value is added added to the `safeAreaInset.top`
     and `safeAreaInsets.bottom`.
     */
    public var verticalPadding: CGFloat = 9.0
    
    /**
     The corner radius. Default is 10.0.
     */
    public var cornerRadius: CGFloat = 10.0;
    
    /**
     The title font. Default is `.boldSystemFont(13.0)`.
     */
    public var titleFont: UIFont = .PingFangTC_400(size: 13)!
    
    /**
     The message font. Default is `.systemFont(ofSize: 13.0)`.
     */
    public var messageFont: UIFont = .PingFangTC_400(size: 13)!
    
    /**
     The title text alignment. Default is `NSTextAlignment.Left`.
     */
    public var titleAlignment: NSTextAlignment = .left
    
    /**
     The message text alignment. Default is `NSTextAlignment.Left`.
     */
    public var messageAlignment: NSTextAlignment = .left
    
    /**
     The maximum number of lines for the title. The default is 0 (no limit).
     */
    public var titleNumberOfLines = 0
    
    /**
     The maximum number of lines for the message. The default is 0 (no limit).
     */
    public var messageNumberOfLines = 0
    
    /**
     Enable or disable a shadow on the toast view. Default is `false`.
     */
    public var displayShadow = false
    
    /**
     The shadow color. Default is `.black`.
     */
    public var shadowColor: UIColor = .black
    
    /**
     A value from 0.0 to 1.0, representing the opacity of the shadow.
     Default is 0.8 (80% opacity).
     */
    public var shadowOpacity: Float = 0.8 {
        didSet {
            shadowOpacity = max(min(shadowOpacity, 1.0), 0.0)
        }
    }
    
    /**
     The shadow radius. Default is 6.0.
     */
    public var shadowRadius: CGFloat = 6.0
    
    /**
     The shadow offset. The default is 4 x 4.
     */
    public var shadowOffset = CGSize(width: 4.0, height: 4.0)
    
    /**
     The image size. The default is 80 x 80.
     */
    public var imageSize = CGSize(width: 80.0, height: 80.0)
    
    /**
     The size of the toast activity view when `makeToastActivity(position:)` is called.
     Default is 100 x 100.
     */
    public var activitySize = CGSize(width: 100.0, height: 100.0)
    
    /**
     The fade in/out animation duration. Default is 0.2.
     */
    public var fadeDuration: TimeInterval = 0.25
    
    /**
     Activity indicator color. Default is `.white`.
     */
    public var activityIndicatorColor: UIColor = .white
    
    /**
     Activity background color. Default is `.black` at 80% opacity.
     */
    public var activityBackgroundColor: UIColor = UIColor.black.withAlphaComponent(0.8)
    
}

// MARK: - Toast Manager

/**
 `ToastManager` provides general configuration options for all toast
 notifications. Backed by a singleton instance.
 */
public class ToastManager {
    
    /**
     The `ToastManager` singleton instance.
     
     */
    public static let shared = ToastManager()
    
    /**
     The shared style. Used whenever toastViewForMessage(message:title:image:style:) is called
     with with a nil style.
     
     */
    public var style = ToastStyle()
    
    /**
     Enables or disables tap to dismiss on toast views. Default is `true`.
     
     */
    public var isTapToDismissEnabled = true
    
    /**
     Enables or disables queueing behavior for toast views. When `true`,
     toast views will appear one after the other. When `false`, multiple toast
     views will appear at the same time (potentially overlapping depending
     on their positions). This has no effect on the toast activity view,
     which operates independently of normal toast views. Default is `false`.
     
     */
    public var isQueueEnabled = false
    
    /**
     The default duration. Used for the `makeToast` and
     `showToast` methods that don't require an explicit duration.
     Default is 3.0.
     
     */
    public var duration: TimeInterval = 3.0
    
    /**
     Sets the default position. Used for the `makeToast` and
     `showToast` methods that don't require an explicit position.
     Default is `ToastPosition.Bottom`.
     
     */
    public var position: ToastPosition = .bottom
    
}

// MARK: - ToastPosition

public enum ToastPosition {
    case top
    case center
    case bottom
    
    fileprivate func centerPoint(forToast toast: UIView, inSuperview superview: UIView) -> CGPoint {
        let topPadding: CGFloat = ToastManager.shared.style.verticalPadding + superview.csSafeAreaInsets.top
        let bottomPadding: CGFloat = ToastManager.shared.style.verticalPadding + superview.csSafeAreaInsets.bottom
        
        switch self {
        case .top:
            return CGPoint(x: superview.bounds.size.width / 2.0, y: (toast.frame.size.height / 2.0) + topPadding)
        case .center:
            return CGPoint(x: superview.bounds.size.width / 2.0, y: superview.bounds.size.height / 2.0)
        case .bottom:
            return CGPoint(x: superview.bounds.size.width / 2.0, y: (superview.bounds.size.height - (toast.frame.size.height / 2.0)) - bottomPadding)
        }
    }
}

// MARK: - Private UIView Extensions

private extension UIView {
    
    var csSafeAreaInsets: UIEdgeInsets {
        if #available(iOS 11.0, *) {
            return self.safeAreaInsets
        } else {
            return .zero
        }
    }
    
}

// 在你 Fork 的 Toast.swift 檔案中
// 找到 extension UIView 的 stackable toast 部分,替換成以下程式碼:

extension UIView {
    
    private static var stackableToastKey: UInt8 = 0
    private static var stackableToastSpacing: CGFloat = 8.0
    
    /// 儲存目前顯示的疊加 toasts
    private var stackableToasts: [UIView] {
        get {
            return objc_getAssociatedObject(self, &UIView.stackableToastKey) as? [UIView] ?? []
        }
        set {
            objc_setAssociatedObject(self, &UIView.stackableToastKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    /**
     顯示可疊加的 Toast,多個 Toast 會往上堆疊
     
     @param message Toast 訊息文字
     @param duration Toast 顯示時長 (預設使用 ToastManager.shared.duration)
     @param position Toast 位置 (預設使用 ToastManager.shared.position)
     @param title 可選的標題文字
     @param image 可選的圖片
     @param style Toast 樣式 (預設使用 ToastManager.shared.style)
     @param completion 完成後的回調
     */
    public func makeStackableToast(_ message: String?,
                                   duration: TimeInterval = ToastManager.shared.duration,
                                   position: ToastPosition = ToastManager.shared.position,
                                   title: String? = nil,
                                   image: UIImage? = nil,
                                   style: ToastStyle = ToastManager.shared.style,
                                   completion: ((_ didTap: Bool) -> Void)? = nil) {
        
        // 使用原本的方法建立 toast view
        guard let toast = try? toastViewForMessage(message,
                                                   title: title,
                                                   image: image,
                                                   style: style) else {
            return
        }
        
        // 先計算偏移(在添加到列表之前)
        let offset = calculateStackableOffset()
        
        // 添加到疊加列表
        stackableToasts.append(toast)
        
        // 顯示 toast
        showStackableToast(toast,
                           duration: duration,
                           position: position,
                           offset: offset,
                           completion: completion)
    }
    
    /**
     顯示帶按鈕的疊加 Toast
     
     @param message Toast 訊息文字
     @param buttonTitle 按鈕文字
     @param duration 顯示時長
     @param position 位置
     @param buttonAction 按鈕點擊回調
     */
    public func makeStackableToastWithButton(
        _ message: String,
        buttonTitle: String = "按鈕",
        duration: TimeInterval = ToastManager.shared.duration,
        position: ToastPosition = ToastManager.shared.position,
        buttonAction: (() -> Void)? = nil
    ) {
        // 建立自訂 Toast View
        let toastView = createToastViewWithButton(
            message: message,
            buttonTitle: buttonTitle,
            buttonAction: buttonAction
        )
        
        // 計算偏移
        let offset = calculateStackableOffset()
        
        // 添加到列表
        stackableToasts.append(toastView)
        
        // 顯示
        showStackableToast(toastView,
                           duration: duration,
                           position: position,
                           offset: offset,
                           completion: nil)
    }
    
    // MARK: - Private Helper
    
    private func createToastViewWithButton(
        message: String,
        buttonTitle: String,
        buttonAction: (() -> Void)?
    ) -> UIView {
        
        let style = ToastManager.shared.style
        
        // 容器 View
        let containerView = UIView()
        containerView.backgroundColor = style.backgroundColor
        containerView.layer.cornerRadius = style.cornerRadius
        containerView.clipsToBounds = true
        
        if style.displayShadow {
            containerView.layer.shadowColor = style.shadowColor.cgColor
            containerView.layer.shadowOpacity = style.shadowOpacity
            containerView.layer.shadowRadius = style.shadowRadius
            containerView.layer.shadowOffset = style.shadowOffset
        }
        
        // ===== 修改：固定佈局，文字最大 263，按鈕固定右側 =====
        
        // 訊息 Label
        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.textColor = style.messageColor
        messageLabel.font = UIFont.PingFangTC_400(size: 13)!
        messageLabel.numberOfLines = 0  // 支援多行
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // 按鈕
        let button = UIButton(type: .system)
        button.setTitle(buttonTitle, for: .normal)
        button.setTitleColor(UIColor(red: 1.0, green: 0.71, blue: 0.31, alpha: 1.0), for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 13.0, weight: .medium)
        button.backgroundColor = .clear
        button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setContentHuggingPriority(.required, for: .horizontal)  // 按鈕不壓縮
        button.setContentCompressionResistancePriority(.required, for: .horizontal)  // 按鈕不被擠壓
        
        // 儲存 action 到 button
        if let action = buttonAction {
            let wrapper = ToastButtonActionWrapper(action: action)
            objc_setAssociatedObject(button, &ToastButtonKeys.action, wrapper, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        
        button.addTarget(self, action: #selector(handleToastButtonTapped(_:)), for: .touchUpInside)
        
        // 添加到容器
        containerView.addSubview(messageLabel)
        containerView.addSubview(button)
        
        // 固定參數
        let maxLabelWidth: CGFloat = 263  // 文字最大寬度
        let spacing: CGFloat = 12  // 間距
        
        // 計算按鈕需要的寬度
        let buttonSize = button.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        let buttonWidth = buttonSize.width
        
        // 計算 label 實際需要的尺寸（最大 263）
        let labelSize = messageLabel.sizeThatFits(CGSize(width: maxLabelWidth, height: CGFloat.greatestFiniteMagnitude))
        let actualLabelWidth = min(labelSize.width, maxLabelWidth)
        
        // 設定固定文字高度為 20
        let textHeight: CGFloat = 20
        
        // 計算容器總寬度
        let containerWidth = style.horizontalPadding + actualLabelWidth + spacing + buttonWidth + style.horizontalPadding
        let containerHeight = max(labelSize.height + (style.verticalPadding * 2), 44)  // 最小高度 44
        
        containerView.frame = CGRect(x: 0, y: 0, width: containerWidth, height: containerHeight)
        
        // 設定約束
        NSLayoutConstraint.activate([
            // Message Label - 固定在左側，最大寬度 263
            messageLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: style.horizontalPadding),
            messageLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: style.verticalPadding),
            messageLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -style.verticalPadding),
            messageLabel.widthAnchor.constraint(lessThanOrEqualToConstant: maxLabelWidth),
            
            // Button - 固定在右側，垂直置中
            button.leadingAnchor.constraint(equalTo: messageLabel.trailingAnchor, constant: spacing),
            button.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -style.horizontalPadding),
            button.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
        
        return containerView
    }
    
    @objc private func handleToastButtonTapped(_ button: UIButton) {
        if let wrapper = objc_getAssociatedObject(button, &ToastButtonKeys.action) as? ToastButtonActionWrapper {
            wrapper.action()
        }
    }
    
    private struct ToastButtonKeys {
        static var action = malloc(1)
    }
    
    private class ToastButtonActionWrapper {
        let action: () -> Void
        
        init(action: @escaping () -> Void) {
            self.action = action
        }
    }
    /**
     顯示可疊加的 Toast (使用自訂 view)
     
     @param toast 自訂的 Toast view
     @param duration 顯示時長
     @param position 位置
     @param completion 完成回調
     */
    public func showStackableToast(_ toast: UIView,
                                   duration: TimeInterval = ToastManager.shared.duration,
                                   position: ToastPosition = ToastManager.shared.position,
                                   completion: ((_ didTap: Bool) -> Void)? = nil) {
        
        // 先計算偏移
        let offset = calculateStackableOffset()
        
        // 如果不在列表中才添加
        if !stackableToasts.contains(toast) {
            stackableToasts.append(toast)
        }
        
        showStackableToast(toast,
                           duration: duration,
                           position: position,
                           offset: offset,
                           completion: completion)
    }
    
    /**
     清除所有疊加的 Toasts
     */
    public func hideAllStackableToasts() {
        for toast in stackableToasts {
            // 取消 timer
            if let timer = objc_getAssociatedObject(toast, &ToastKeys.timer) as? Timer {
                timer.invalidate()
            }
            
            UIView.animate(withDuration: 0.2, animations: {
                toast.alpha = 0.0
            }) { _ in
                toast.removeFromSuperview()
            }
        }
        stackableToasts.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func calculateStackableOffset() -> CGFloat {
        var offset: CGFloat = 0
        for toast in stackableToasts {
            offset += toast.frame.height + UIView.stackableToastSpacing
        }
        return offset
    }
    
    private func showStackableToast(_ toast: UIView,
                                    duration: TimeInterval,
                                    position: ToastPosition,
                                    offset: CGFloat,
                                    completion: ((_ didTap: Bool) -> Void)?) {
        
        // 先添加到 superview 以便計算 frame
        addSubview(toast)
        
        // 強制布局以獲得正確的 frame size
        toast.setNeedsLayout()
        toast.layoutIfNeeded()
        
        // 設定初始透明度
        toast.alpha = 0.0
        
        // 計算位置 (使用已經計算好的 offset)
        let point = position.centerPoint(forToast: toast, inSuperview: self, offset: offset)
        toast.center = point
        
        // 淡入動畫
        UIView.animate(withDuration: ToastManager.shared.style.fadeDuration,
                       delay: 0.0,
                       options: [.curveEaseOut, .allowUserInteraction],
                       animations: {
            toast.alpha = 1.0
        })
        
        // 設定自動隱藏
        let timer = Timer(timeInterval: duration,
                          target: self,
                          selector: #selector(hideStackableToast(_:)),
                          userInfo: ["toast": toast, "completion": completion as Any],
                          repeats: false)
        RunLoop.main.add(timer, forMode: .common)
        objc_setAssociatedObject(toast, &ToastKeys.timer, timer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // 點擊手勢
        if ToastManager.shared.isTapToDismissEnabled {
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleStackableToastTapped(_:)))
            toast.addGestureRecognizer(recognizer)
            toast.isUserInteractionEnabled = true
            toast.isExclusiveTouch = true
        }
    }
    
    @objc private func hideStackableToast(_ timer: Timer) {
        guard let userInfo = timer.userInfo as? [String: Any],
              let toast = userInfo["toast"] as? UIView else {
            return
        }
        
        let completion = userInfo["completion"] as? ((Bool) -> Void)
        hideStackableToast(toast, fromTap: false, completion: completion)
    }
    
    private func hideStackableToast(_ toast: UIView,
                                    fromTap: Bool,
                                    completion: ((_ didTap: Bool) -> Void)?) {
        
        // 取消 timer
        if let timer = objc_getAssociatedObject(toast, &ToastKeys.timer) as? Timer {
            timer.invalidate()
        }
        
        // 淡出動畫
        UIView.animate(withDuration: 0.3,
                       delay: 0.0,
                       options: [.curveEaseIn, .beginFromCurrentState],
                       animations: {
            toast.alpha = 0.0
        }) { _ in
            toast.removeFromSuperview()
            
            // 從列表移除
            if let index = self.stackableToasts.firstIndex(of: toast) {
                self.stackableToasts.remove(at: index)
            }
            
            // 重新排列剩餘的 toasts
            self.rearrangeStackableToasts()
            
            // 執行完成回調
            completion?(fromTap)
        }
    }
    
    @objc private func handleStackableToastTapped(_ recognizer: UITapGestureRecognizer) {
        guard let toast = recognizer.view else { return }
        
        // 取得 completion
        if let timer = objc_getAssociatedObject(toast, &ToastKeys.timer) as? Timer,
           let userInfo = timer.userInfo as? [String: Any],
           let completion = userInfo["completion"] as? ((Bool) -> Void) {
            hideStackableToast(toast, fromTap: true, completion: completion)
        } else {
            hideStackableToast(toast, fromTap: true, completion: nil)
        }
    }
    
    private func rearrangeStackableToasts() {
        guard !stackableToasts.isEmpty else { return }
        
        UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveEaseOut, animations: {
            var offset: CGFloat = 0
            let position = ToastManager.shared.position
            
            // 重新計算每個 toast 的位置
            for toast in self.stackableToasts {
                let point = position.centerPoint(forToast: toast, inSuperview: self, offset: offset)
                toast.center = point
                
                // 累加偏移量
                offset += toast.frame.height + UIView.stackableToastSpacing
            }
        })
    }
}

// MARK: - ToastPosition Extension
extension ToastPosition {
    
    func centerPoint(forToast toast: UIView, inSuperview superview: UIView, offset: CGFloat) -> CGPoint {
        let topPadding: CGFloat = ToastManager.shared.style.verticalPadding + superview.csSafeAreaInsets.top
        let bottomPadding: CGFloat = ToastManager.shared.style.verticalPadding + superview.csSafeAreaInsets.bottom
        
        switch self {
        case .top:
            // Top position: 新的 toast 在上方 (offset 往下推)
            return CGPoint(x: superview.bounds.size.width / 2.0,
                           y: (toast.frame.size.height / 2.0) + topPadding + offset)
        case .center:
            // Center position: 新的 toast 往上推
            return CGPoint(x: superview.bounds.size.width / 2.0,
                           y: (superview.bounds.size.height / 2.0) - offset)
        case .bottom:
            // Bottom position: 距離 safeArea 底部 64
            let customBottomOffset: CGFloat = 64.0  // 新增：自訂距離
            return CGPoint(x: superview.bounds.size.width / 2.0,
                           y: (superview.bounds.size.height - superview.csSafeAreaInsets.bottom - customBottomOffset - (toast.frame.size.height / 2.0)) - offset)
        }
    }
}

extension UIFont{
    /** PingFangTC-Light */
    static func PingFangTC_300(size: CGFloat) -> UIFont?{
        return UIFont.init(name: "PingFangTC-Light", size: size)
    }
    
    /** PingFangTC-Regular */
    static func PingFangTC_400(size: CGFloat) -> UIFont?{
        return UIFont.init(name: "PingFangTC-Regular", size: size)
    }
    
    /** PingFangTC-Medium */
    static func PingFangTC_500(size: CGFloat) -> UIFont?{
        return UIFont.init(name: "PingFangTC-Medium", size: size)
    }
    
    /** PingFangTC-Semibold */
    static func PingFangTC_600(size: CGFloat) -> UIFont?{
        return UIFont.init(name: "PingFangTC-Semibold", size: size)
    }
    
    /** NotoSans-Light */
    static func NotoSans_300(size: CGFloat) -> UIFont?{
        return UIFont.init(name: "NotoSans-Light", size: size)
    }
    
    /** NotoSans-Regular */
    static func NotoSans_400(size: CGFloat) -> UIFont?{
        return UIFont.init(name: "NotoSans-Regular", size: size)
    }
    
    /** NotoSans-Medium */
    static func NotoSans_500(size: CGFloat) -> UIFont?{
        return UIFont.init(name: "NotoSans-Medium", size: size)
    }
    
    /** NotoSans-Light */
    static func NotoSansJP_300(size: CGFloat) -> UIFont?{
        return UIFont.init(name: "NotoSansJP-Light", size: size)
    }
    
    /** NotoSans-Regular */
    static func NotoSansJP_400(size: CGFloat) -> UIFont?{
        return UIFont.init(name: "NotoSansJP-Regular", size: size)
    }
    
    /** NotoSans-Medium */
    static func NotoSansJP_500(size: CGFloat) -> UIFont?{
        return UIFont.init(name: "NotoSansJP-Medium", size: size)
    }
    
    /** NotoSans-Medium */
    static func NotoSansJP_700(size: CGFloat) -> UIFont?{
        return UIFont.init(name: "NotoSansJP-Bold", size: size)
    }
}
