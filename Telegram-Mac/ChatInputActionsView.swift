//
//  ChatInputActionsView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 26/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac


//
let iconsInset:CGFloat = 20.0

class ChatInputActionsView: View, Notifable {
    
    let chatInteraction:ChatInteraction
    private let send:ImageButton = ImageButton()
    private let voice:ImageButton = ImageButton()
    private let muteChannelMessages:ImageButton = ImageButton()
    private let entertaiments:ImageButton = ImageButton()
    private let inlineCancel:ImageButton = ImageButton()
    private let keyboard:ImageButton = ImageButton()
    private var secretTimer:ImageButton?
    
    init(frame frameRect: NSRect, chatInteraction:ChatInteraction) {
        self.chatInteraction = chatInteraction
       
        super.init(frame: frameRect)
        
        addSubview(keyboard)
        addSubview(send)
        addSubview(voice)
        addSubview(inlineCancel)
        addSubview(muteChannelMessages)
        inlineCancel.isHidden = true
        send.isHidden = true
        voice.isHidden = true
        muteChannelMessages.isHidden = true
        
        voice.autohighlight = false
        muteChannelMessages.autohighlight = false
        
        voice.set(handler: { [weak self] _ in
            FastSettings.toggleRecordingState()
            self?.voice.set(image: FastSettings.recordingState == .voice ? theme.icons.chatRecordVoice : theme.icons.chatRecordVideo, for: .Normal)
        }, for: .Click)
        
        voice.set(handler: { [weak self] _ in
            if let peer = self?.chatInteraction.presentation.peer, peer.mediaRestricted {
                alertForMediaRestriction(peer)
            }
        }, for: .Up)
        
        voice.set(handler: { [weak self] _ in
            self?.stop()
        }, for: .Up)
        
        
        
        voice.set(handler: { [weak self] _ in
            if let strongSelf = self, let peer = strongSelf.chatInteraction.presentation.peer {
                if peer.mediaRestricted {
                    return alertForMediaRestriction(peer)
                }
                if strongSelf.chatInteraction.presentation.effectiveInput.inputText.isEmpty {
                    strongSelf.start()
                }
            }
        }, for: .LongMouseDown)
        
        voice.set(handler: { [weak self] _ in
            if let peer = self?.chatInteraction.presentation.peer, peer.mediaRestricted {
                alertForMediaRestriction(peer)
            }
        }, for: .Up)
        
        muteChannelMessages.set(handler: { [weak self] _ in
            if let chatInteraction = self?.chatInteraction {
                FastSettings.toggleChannelMessagesMuted(chatInteraction.peerId)
                (self?.superview?.superview as? View)?.updateLocalizationAndTheme()
            }
        }, for: .Click)


        keyboard.set(handler: { [weak self] _ in
            self?.toggleKeyboard()
        }, for: .Up)
        
        inlineCancel.set(handler: { [weak self] _ in
            if let inputContext = self?.chatInteraction.presentation.inputContext, case let .contextRequest(request) = inputContext {
                if request.query.isEmpty {
                    self?.chatInteraction.clearInput()
                } else {
                    self?.chatInteraction.clearContextQuery()
                }
            }
        }, for: .Up)

        entertaiments.highlightHovered = true
        addSubview(entertaiments)
        
        addHoverObserver()
        addClickObserver()
        entertaiments.canHighlight = false
        
        updateLocalizationAndTheme()
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        send.set(image: theme.icons.chatSendMessage, for: .Normal)
        send.sizeToFit()
        voice.set(image: FastSettings.recordingState == .voice ? theme.icons.chatRecordVoice : theme.icons.chatRecordVideo, for: .Normal)
        voice.sizeToFit()
        
        let muted = FastSettings.isChannelMessagesMuted(chatInteraction.peerId)
        muteChannelMessages.set(image: !muted ? theme.icons.inputChannelMute : theme.icons.inputChannelUnmute, for: .Normal)
        muteChannelMessages.sizeToFit()
        
        
        keyboard.set(image: theme.icons.chatActiveReplyMarkup, for: .Normal)
        keyboard.sizeToFit()
        inlineCancel.set(image: theme.icons.chatInlineDismiss, for: .Normal)
        inlineCancel.sizeToFit()
        entertaiments.set(image: chatInteraction.presentation.isEmojiSection ? theme.icons.chatEntertainment : theme.icons.chatEntertainmentSticker, for: .Normal)
        entertaiments.sizeToFit()
        secretTimer?.set(image: theme.icons.chatSecretTimer, for: .Normal)

    }
    
    private func addHoverObserver() {
        
        entertaiments.set(handler: { [weak self] (state) in
            if let strongSelf = self {
                let chatInteraction = strongSelf.chatInteraction
                var enabled = false
                
                if let sidebarEnabled = chatInteraction.presentation.sidebarEnabled {
                    enabled = sidebarEnabled
                }
                if !((mainWindow.frame.width >= 1100 && chatInteraction.account.context.layout == .dual) || (mainWindow.frame.width >= 880 && chatInteraction.account.context.layout == .minimisize)) || !enabled {
                    if !hasPopover(mainWindow) {
                        let rect = NSMakeRect(0, 0, 350, 350)
                        chatInteraction.account.context.entertainment._frameRect = rect
                        chatInteraction.account.context.entertainment.view.frame = rect
                        showPopover(for: strongSelf.entertaiments, with: chatInteraction.account.context.entertainment, edge: .maxX, inset:NSMakePoint(strongSelf.frame.width - strongSelf.entertaiments.frame.maxX + 15, 10), delayBeforeShown: 0.0)
                    }
                    
                }
            }
        }, for: .Hover)
    }
    
    private func addClickObserver() {
        entertaiments.set(handler: { [weak self] (state) in
            if let strongSelf = self {
                let chatInteraction = strongSelf.chatInteraction
                if let sidebarEnabled = chatInteraction.presentation.sidebarEnabled, sidebarEnabled {
                    if mainWindow.frame.width >= 1100 && chatInteraction.account.context.layout == .dual || mainWindow.frame.width >= 880 && chatInteraction.account.context.layout == .minimisize {
                        
                        chatInteraction.toggleSidebar()
                    }
                }
            }
        }, for: .Click)
    }
    
    
    func toggleKeyboard() {
        let keyboardId = chatInteraction.presentation.keyboardButtonsMessage?.id
        chatInteraction.update({$0.updatedInterfaceState({$0.withUpdatedMessageActionsState({ actions in
            let nid = actions.closedButtonKeyboardMessageId != nil ? nil : keyboardId
            return actions.withUpdatedClosedButtonKeyboardMessageId(nid)
        })})})
    }
    
    override func layout() {
        super.layout()
        inlineCancel.centerY(x:frame.width - inlineCancel.frame.width - iconsInset)
        voice.centerY(x:frame.width - voice.frame.width - iconsInset)
        send.centerY(x: frame.width - send.frame.width - iconsInset)
        entertaiments.centerY(x: voice.frame.minX - entertaiments.frame.width - iconsInset)
        secretTimer?.centerY(x: entertaiments.frame.minX - keyboard.frame.width - iconsInset)
        keyboard.centerY(x: entertaiments.frame.minX - keyboard.frame.width - iconsInset)
        muteChannelMessages.centerY(x: entertaiments.frame.minX - muteChannelMessages.frame.width - iconsInset)
        
    }
    
    func stop() {

        let chatInteraction = self.chatInteraction
        if let recorder = chatInteraction.presentation.recordingState {
            if canSend {
                recorder.stop()
                chatInteraction.mediaPromise.set(recorder.data)
            } else {
                recorder.dispose()
            }
            closeAllModals()
        }
         chatInteraction.update({$0.withoutRecordingState()})
       
    }
    
    var canSend:Bool {
        if let superview = superview, let window = window {
            let mouse = superview.convert(window.mouseLocationOutsideOfEventStream, from: nil)
            let inside = NSPointInRect(mouse, superview.frame)
            return inside
        }
        return false
    }
    
    func start() {
        let state: ChatRecordingState
        
        switch FastSettings.recordingState {
        case .voice:
            state = ChatRecordingAudioState()
            state.start()
        case .video:
            state = ChatRecordingVideoState()
            showModal(with: VideoRecorderModalController(chatInteraction: chatInteraction, pipeline: (state as! ChatRecordingVideoState).pipeline), for: mainWindow)
        }
     
        chatInteraction.update({$0.withRecordingState(state)})
    }
    
    private var first:Bool = true
    func notify(with value: Any, oldValue: Any, animated:Bool) {
        if let value = value as? ChatPresentationInterfaceState, let oldValue = oldValue as? ChatPresentationInterfaceState {
            if value.interfaceState != oldValue.interfaceState || value.editState != oldValue.editState || !animated || value.inputQueryResult != oldValue.inputQueryResult || value.inputContext != oldValue.inputContext || value.sidebarEnabled != oldValue.sidebarEnabled || value.sidebarShown != oldValue.sidebarShown || value.layout != oldValue.layout {
            
                var size:NSSize = NSMakeSize(send.frame.width + iconsInset + entertaiments.frame.width + iconsInset * 2, frame.height)
                
                if chatInteraction.peerId.namespace == Namespaces.Peer.SecretChat {
                    size.width += theme.icons.chatSecretTimer.backingSize.width + iconsInset
                }
              
                if let peer = value.peer {
                    muteChannelMessages.isHidden = !peer.isChannel || !peer.canSendMessage
                }
                
                if !muteChannelMessages.isHidden {
                    size.width += muteChannelMessages.frame.width + iconsInset
                }
                
                var newInlineRequest = value.inputQueryResult != oldValue.inputQueryResult
                var oldInlineRequest = newInlineRequest
                if let query = value.inputQueryResult, case .contextRequestResult = query, newInlineRequest || first {
                    newInlineRequest = true
                } else {
                    newInlineRequest = false
                }
                
                
                if let query = oldValue.inputQueryResult, case .contextRequestResult = query, oldInlineRequest || first {
                    oldInlineRequest = true
                } else {
                    oldInlineRequest = false
                }
                
                let sNew = !value.effectiveInput.inputText.isEmpty || !value.interfaceState.forwardMessageIds.isEmpty || value.state == .editing
                let sOld = !oldValue.effectiveInput.inputText.isEmpty || !oldValue.interfaceState.forwardMessageIds.isEmpty || oldValue.state == .editing
                
                let anim = animated && (sNew != sOld || newInlineRequest != oldInlineRequest)
                if sNew != sOld || first || newInlineRequest != oldInlineRequest {
                    first = false
                    
                    let prevView:View
                    let newView:View
                    
                    if newInlineRequest {
                        prevView = !sOld ? voice : send
                        newView = inlineCancel
                    } else if oldInlineRequest {
                        prevView = inlineCancel
                        newView = sNew ? send : voice
                    } else {
                        prevView = sNew ? voice : send
                        newView = sNew ? send : voice
                    }

                    
                    newView.isHidden = false
                    newView.layer?.opacity = 1.0
                    prevView.layer?.opacity = 0.0
                    if anim {
                        newView.layer?.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
                        newView.layer?.animateScaleSpring(from: 0.1, to: 1.0, duration: 0.6)
                        prevView.layer?.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion:{ complete in
                            if complete {
                                prevView.isHidden = true
                            }
                        })
                    } else {
                        prevView.isHidden = true
                    }
                }
                
                entertaiments.apply(state: .Normal)
                entertaiments.isSelected = value.isShowSidebar || (chatInteraction.account.context.entertainment.popover?.isShown ?? false)
                
                keyboard.isHidden = !value.isKeyboardActive
                
                if let keyboardMessage = value.keyboardButtonsMessage {
                   // if value.state == .normal && (value.effectiveInput.inputText.isEmpty || value.isKeyboardShown) {
                        size.width += keyboard.frame.width + iconsInset
                   // }
                    if let closedId = value.interfaceState.messageActionsState.closedButtonKeyboardMessageId, closedId == keyboardMessage.id {
                        self.keyboard.set(image: theme.icons.chatDisabledReplyMarkup, for: .Normal)
                    } else {
                        self.keyboard.set(image: theme.icons.chatActiveReplyMarkup, for: .Normal)
                    }

                }
                self.change(size: size, animated: false)
                
           
                
                self.needsLayout = true
            } else if value.isEmojiSection != oldValue.isEmojiSection {
                entertaiments.set(image: value.isEmojiSection ? theme.icons.chatEntertainment : theme.icons.chatEntertainmentSticker, for: .Normal)
            }
        }
    }
    
    func isEqual(to other: Notifable) -> Bool {
        if let other = other as? ChatInputActionsView {
            return self == other
        }
        return false
    }
    
    deinit {
        chatInteraction.remove(observer: self)
    }
    
    func prepare(with chatInteraction:ChatInteraction) -> Void {
        send.set(handler: { _ in
            chatInteraction.sendMessage()
        }, for: .Click)
        
        chatInteraction.add(observer: self)
        notify(with: chatInteraction.presentation, oldValue: chatInteraction.presentation, animated: false)
        
        if chatInteraction.peerId.namespace == Namespaces.Peer.SecretChat {
            secretTimer = ImageButton()
            secretTimer?.set(image: theme.icons.chatSecretTimer, for: .Normal)
            secretTimer?.sizeToFit()
            addSubview(secretTimer!)
            
            secretTimer?.set(handler: { [weak self] control in
                if let strongSelf = self {
                    showPopover(for: control, with: SPopoverViewController(items:strongSelf.secretTimerItems(), visibility: 6), edge: .maxX, inset:NSMakePoint(120, 10))
                }
            }, for: .Click)
        }
    }
    
    func performSendMessage() {
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    func secretTimerItems() -> [SPopoverItem] {
        
        var items:[SPopoverItem] = []
        
        if let peer = chatInteraction.presentation.peer as? TelegramSecretChat {
            if peer.messageAutoremoveTimeout != nil {
                
                items.append(SPopoverItem(tr(.secretTimerOff), { [weak self] in
                    self?.chatInteraction.setSecretChatMessageAutoremoveTimeout(nil)
                }))
            }
        }
        
        
        for i in 0 ..< 30 {
            
            items.append(SPopoverItem(tr(.timerSecondsCountable(i + 1)), { [weak self] in
                self?.chatInteraction.setSecretChatMessageAutoremoveTimeout(Int32(i + 1))
            }))
        }
        
        items.append(SPopoverItem(tr(.timerMinutesCountable(1)), { [weak self] in
            self?.chatInteraction.setSecretChatMessageAutoremoveTimeout(60)
        }))
        
        items.append(SPopoverItem(tr(.timerHoursCountable(1)), { [weak self] in
            self?.chatInteraction.setSecretChatMessageAutoremoveTimeout(60 * 60)
        }))
        
        items.append(SPopoverItem(tr(.timerDaysCountable(1)), { [weak self] in
            self?.chatInteraction.setSecretChatMessageAutoremoveTimeout(60 * 60 * 24)
        }))
        
        items.append(SPopoverItem(tr(.timerWeeksCountable(1)), { [weak self] in
            self?.chatInteraction.setSecretChatMessageAutoremoveTimeout(60 * 60 * 24 * 7)
        }))
        
        return items
    }
    
    
}
