//
//  AttachmentManager.swift
//  InputBarAccessoryView
//
//  Copyright © 2017-2020 Nathan Tannar.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//
//  Created by Nathan Tannar on 10/4/17.
//

import UIKit
import AVFoundation

open class AttachmentManager: NSObject, InputPlugin {
    
    public enum Attachment {
        case image(UIImage)
        case url(URL)
        case data(Data)
        
        @available(*, deprecated, message: ".other(AnyObject) has been depricated as of 2.0.0")
        case other(AnyObject)
    }
    
    // MARK: - Properties [Public]
    
    /// A protocol that can recieve notifications from the `AttachmentManager`
    open weak var delegate: AttachmentManagerDelegate?
    
    /// A protocol to passes data to the `AttachmentManager`
    open weak var dataSource: AttachmentManagerDataSource?
    
    open lazy var attachmentView: AttachmentCollectionView = { [weak self] in
        let attachmentView = AttachmentCollectionView()
        attachmentView.dataSource = self
        attachmentView.delegate = self
        return attachmentView
    }()
    
    /// The attachments that the managers holds
    private(set) public var attachments = [Attachment]() { didSet { reloadData() } }
    
    /// A flag you can use to determine if you want the manager to be always visible
    open var isPersistent = false { didSet { attachmentView.reloadData() } }
    
    /// A flag to determine if the AddAttachmentCell is visible
    open var showAddAttachmentCell = true { didSet { attachmentView.reloadData() } }
    
    /// The color applied to the backgroundColor of the deleteButton in each `AttachmentCell`
    open var tintColor: UIColor {
        if #available(iOS 13, *) {
            return .link
        } else {
            return .systemBlue
        }
    }
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
    }
    
    // MARK: - InputPlugin
    
    open func reloadData() {
        attachmentView.reloadData()
        delegate?.attachmentManager(self, didReloadTo: attachments)
        delegate?.attachmentManager(self, shouldBecomeVisible: attachments.count > 0 || isPersistent)
    }
    
    /// Invalidates the `AttachmentManagers` session by removing all attachments
    open func invalidate() {
        attachments = []
    }
    
    /// Appends the object to the attachments
    ///
    /// - Parameter object: The object to append
    @discardableResult
    open func handleInput(of object: AnyObject) -> Bool {
        let attachment: Attachment
        if let image = object as? UIImage {
            attachment = .image(image)
        } else if let url = object as? URL {
            attachment = .url(url)
        } else if let data = object as? Data {
            attachment = .data(data)
        } else {
            return false
        }
        
        insertAttachment(attachment, at: attachments.count)
        return true
    }
    
    // MARK: - API [Public]
    
    /// Performs an animated insertion of an attachment at an index
    ///
    /// - Parameter index: The index to insert the attachment at
    open func insertAttachment(_ attachment: Attachment, at index: Int) {
        
        attachmentView.performBatchUpdates({
            self.attachments.insert(attachment, at: index)
            self.attachmentView.insertItems(at: [IndexPath(row: index, section: 0)])
        }, completion: { success in
            self.attachmentView.reloadData()
            self.delegate?.attachmentManager(self, didInsert: attachment, at: index)
            self.delegate?.attachmentManager(self, shouldBecomeVisible: self.attachments.count > 0 || self.isPersistent)
        })
    }
    
    /// Performs an animated removal of an attachment at an index
    ///
    /// - Parameter index: The index to remove the attachment at
    open func removeAttachment(at index: Int) {
        
        let attachment = attachments[index]
        attachmentView.performBatchUpdates({
            self.attachments.remove(at: index)
            self.attachmentView.deleteItems(at: [IndexPath(row: index, section: 0)])
        }, completion: { success in
            self.attachmentView.reloadData()
            self.delegate?.attachmentManager(self, didRemove: attachment, at: index)
            self.delegate?.attachmentManager(self, shouldBecomeVisible: self.attachments.count > 0 || self.isPersistent)
        })
    }
    
}

extension AttachmentManager: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    // MARK: - UICollectionViewDelegate
    
    final public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.row == attachments.count {
            delegate?.attachmentManager(self, didSelectAddAttachmentAt: indexPath.row)
            delegate?.attachmentManager(self, shouldBecomeVisible: attachments.count > 0 || isPersistent)
        }
    }
    
    // MARK: - UICollectionViewDataSource
    
    final public func numberOfItems(inSection section: Int) -> Int {
        return 1
    }
    
    final public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return attachments.count + (showAddAttachmentCell ? 1 : 0)
    }
    
    final public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        if indexPath.row == attachments.count && showAddAttachmentCell {
            return createAttachmentCell(in: collectionView, at: indexPath)
        }
        
        let attachment = attachments[indexPath.row]
        
        if let cell = dataSource?.attachmentManager(self, cellFor: attachment, at: indexPath.row) {
            return cell
        } else {
            
            // Only images are supported by default
            switch attachment {
            case .image(let image):
                guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ImageAttachmentCell.reuseIdentifier, for: indexPath) as? ImageAttachmentCell else {
                    fatalError()
                }
                cell.attachment = attachment
                cell.indexPath = indexPath
                cell.manager = self
                cell.imageView.image = image
                cell.imageView.tintColor = tintColor
                cell.deleteButton.backgroundColor = tintColor
                return cell
            case .url(let url):
                guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ImageAttachmentCell.reuseIdentifier, for: indexPath) as? ImageAttachmentCell else {
                    fatalError()
                }
                cell.attachment = attachment
                cell.indexPath = indexPath
                cell.manager = self
                generateThumbnailImage(from: url) { thumbnailImage in
                    cell.imageView.image = thumbnailImage
                    let p = PlayButtonView()
                    cell.imageView.addSubview(p)
                    p.centerInSuperview()
                    p.constraint(equalTo: CGSize(width: 15, height: 15))
                }
                
                cell.imageView.tintColor = tintColor
                cell.deleteButton.backgroundColor = tintColor
                return cell
            default:
                return collectionView.dequeueReusableCell(withReuseIdentifier: AttachmentCell.reuseIdentifier, for: indexPath) as! AttachmentCell
            }
        }
    }

    func generateThumbnailImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        let asset = AVAsset(url: url)
        let assetImageGenerator = AVAssetImageGenerator(asset: asset)
        
        // Set the maximum size of the thumbnail image
        let maxSize = CGSize(width: 720, height: 720)
        assetImageGenerator.maximumSize = maxSize
        
        // Get the time for the middle of the video
        let duration = asset.duration
        let middleTime = CMTimeMultiplyByFloat64(duration, multiplier: 0.5)
        
        // Generate the thumbnail image
        assetImageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: middleTime)]) { _, cgImage, _, _, _ in
            guard let cgImage = cgImage else {
                completion(nil)
                return
            }
            let thumbnailImage = UIImage(cgImage: cgImage)
            DispatchQueue.main.async {
                completion(thumbnailImage)
            }
        }
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    
    final public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        if let customSize = self.dataSource?.attachmentManager(self, sizeFor: self.attachments[indexPath.row], at: indexPath.row){
            return customSize
        }
        
        var height = attachmentView.intrinsicContentHeight
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            height -= (layout.sectionInset.bottom + layout.sectionInset.top + collectionView.contentInset.top + collectionView.contentInset.bottom)
        }
        return CGSize(width: height, height: height)
    }
    
    @objc open func createAttachmentCell(in collectionView: UICollectionView, at indexPath: IndexPath) -> AttachmentCell {
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AttachmentCell.reuseIdentifier, for: indexPath) as? AttachmentCell else {
            fatalError()
        }
        cell.deleteButton.isHidden = true
        // Draw a plus
        let frame = CGRect(origin: CGPoint(x: cell.bounds.origin.x,
                                           y: cell.bounds.origin.y),
                           size: CGSize(width: cell.bounds.width - cell.padding.left - cell.padding.right,
                                        height: cell.bounds.height - cell.padding.top - cell.padding.bottom))
        let strokeWidth: CGFloat = 3
        let length: CGFloat = frame.width / 2
        let grayColor: UIColor
        if #available(iOS 13, *) {
            grayColor = .systemGray2
        } else {
            grayColor = .lightGray
        }
        let vLayer = CAShapeLayer()
        vLayer.path = UIBezierPath(roundedRect: CGRect(x: frame.midX - (strokeWidth / 2),
                                                       y: frame.midY - (length / 2),
                                                       width: strokeWidth,
                                                       height: length), cornerRadius: 5).cgPath
        vLayer.fillColor = grayColor.cgColor
        let hLayer = CAShapeLayer()
        hLayer.path = UIBezierPath(roundedRect: CGRect(x: frame.midX - (length / 2),
                                                       y: frame.midY - (strokeWidth / 2),
                                                       width: length,
                                                       height: strokeWidth), cornerRadius: 5).cgPath
        hLayer.fillColor = grayColor.cgColor
        cell.containerView.layer.addSublayer(vLayer)
        cell.containerView.layer.addSublayer(hLayer)
        return cell
    }
}


open class PlayButtonView: UIView {
  // MARK: Lifecycle

  // MARK: - Initializers

  public override init(frame: CGRect) {
    super.init(frame: frame)

    setupSubviews()
    setupConstraints()
    setupView()
  }

  required public init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)

    setupSubviews()
    setupConstraints()
    setupView()
  }

  // MARK: Open

  // MARK: - Methods

  open override func layoutSubviews() {
    super.layoutSubviews()

    guard !cacheFrame.equalTo(frame) else { return }
    cacheFrame = frame

    updateTriangleConstraints()
    applyCornerRadius()
    applyTriangleMask()
  }

  // MARK: Public

  // MARK: - Properties

  public let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
  public let triangleView = UIView()

  // MARK: Private

  private var triangleCenterXConstraint: NSLayoutConstraint?
  private var cacheFrame: CGRect = .zero

  private func setupSubviews() {
    addSubview(blurView)
    addSubview(triangleView)
  }

  private func setupView() {
    triangleView.clipsToBounds = true
    triangleView.backgroundColor = .black
    blurView.clipsToBounds = true
    backgroundColor = .clear
  }

  private func setupConstraints() {
    triangleView.translatesAutoresizingMaskIntoConstraints = false

    let centerX = triangleView.centerXAnchor.constraint(equalTo: centerXAnchor)
    let centerY = triangleView.centerYAnchor.constraint(equalTo: centerYAnchor)
    let width = triangleView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.5)
    let height = triangleView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.5)

    triangleCenterXConstraint = centerX

    NSLayoutConstraint.activate([centerX, centerY, width, height])

    blurView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      blurView.centerXAnchor.constraint(equalTo: centerXAnchor),
      blurView.centerYAnchor.constraint(equalTo: centerYAnchor),
      blurView.heightAnchor.constraint(equalTo: heightAnchor),
      blurView.widthAnchor.constraint(equalTo: widthAnchor),
    ])
  }

  private func triangleMask(for frame: CGRect) -> CAShapeLayer {
    let shapeLayer = CAShapeLayer()
    let trianglePath = UIBezierPath()

    let point1 = CGPoint(x: frame.minX, y: frame.minY)
    let point2 = CGPoint(x: frame.maxX, y: frame.maxY / 2)
    let point3 = CGPoint(x: frame.minX, y: frame.maxY)

    trianglePath.move(to: point1)
    trianglePath.addLine(to: point2)
    trianglePath.addLine(to: point3)
    trianglePath.close()

    shapeLayer.path = trianglePath.cgPath

    return shapeLayer
  }

  private func updateTriangleConstraints() {
    triangleCenterXConstraint?.constant = triangleView.frame.width / 8
  }

  private func applyTriangleMask() {
    let rect = CGRect(origin: .zero, size: triangleView.bounds.size)
    triangleView.layer.mask = triangleMask(for: rect)
  }

  private func applyCornerRadius() {
    blurView.layer.cornerRadius = frame.width / 2
  }
}

extension UIView {
    func centerInSuperview() {
        guard let superview = superview else {
            return
        }
        translatesAutoresizingMaskIntoConstraints = false
        let constraints: [NSLayoutConstraint] = [
            centerXAnchor.constraint(equalTo: superview.centerXAnchor),
            centerYAnchor.constraint(equalTo: superview.centerYAnchor),
        ]
        NSLayoutConstraint.activate(constraints)
  }

    func constraint(equalTo size: CGSize) {
        guard superview != nil else { return }
        translatesAutoresizingMaskIntoConstraints = false
        let constraints: [NSLayoutConstraint] = [
            widthAnchor.constraint(equalToConstant: size.width),
            heightAnchor.constraint(equalToConstant: size.height),
        ]
        NSLayoutConstraint.activate(constraints)
    }
}
