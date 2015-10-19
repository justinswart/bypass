//
//  BPAttributedStringRenderer.m
//  Bypass
//
//  Created by Damian Carrillo on 3/1/13.
//  Copyright 2013 Uncodin, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <CoreText/CoreText.h>
#import "BPAttributedStringConverter.h"
#import "BPDisplaySettings.h"

NSString *const BPLinkStyleAttributeName = @"NSLinkAttributeName";

@interface BPAttributedStringConverter ()
@property(nonatomic) BOOL renderedFirstParagraph;
@end

@implementation BPAttributedStringConverter

#pragma mark Lifecycle

- (id)init {
    if ((self = [super init])) {
        _displaySettings = [[BPDisplaySettings alloc] init];
    }

    return self;
}

#pragma mark Rendering

- (NSAttributedString *)convertDocument:(BPDocument *)document
{
    NSMutableAttributedString *target = [[NSMutableAttributedString alloc] init];

    [target addAttribute:NSForegroundColorAttributeName value:[_displaySettings defaultColor] range:NSMakeRange(0, target.length)];
    
    for (BPElement *element in [document elements]) {
        [self convertElement:element toTarget:target];
    }
    
    NSMutableParagraphStyle *paragraphyStyle = [[NSMutableParagraphStyle alloc] init];
    [paragraphyStyle setAlignment:_displaySettings.defaultAlignment];
    [target addAttribute:NSParagraphStyleAttributeName value:paragraphyStyle range:NSMakeRange(0, target.length)];
    
    return target;
}

- (BOOL)markdownContainsList:(BPDocument *)document
{
    for (BPElement *element in [document elements]) {
        if ([element elementType] == BPList)
            return YES;
    }
    
    return NO;
}

- (void)convertElement:(BPElement *)element toTarget:(NSMutableAttributedString *)target
{
    // Capture the starting point of the effective range to apply attributes to
    
    NSRange effectiveRange;
    effectiveRange.location = [target length];
 
    BPElementType elementType = [element elementType];
    
    // Render span elements immediately, and for some block-level elements, insert special
    // characters
    
    if (elementType == BPList) {
        [self insertNewlineIntoTarget:target];
    } else if (elementType == BPAutoLink) {
        [self renderLinkElement:element toTarget:target];
    } else if (elementType == BPCodeSpan) {
        [self renderCodeSpanElement:element toTarget:target];
    } else if (elementType == BPDoubleEmphasis) {
        [self renderBoldElement:element toTarget:target];
    } else if (elementType == BPEmphasis) {
        [self renderItalicElement:element toTarget:target];
    } else if (elementType == BPImage) {
        // Currently not supported
    } else if (elementType == BPLineBreak) {
        [self renderLineBreak:element toTarget:target];
    } else if (elementType == BPLink) {
        [self renderLinkElement:element toTarget:target];
    } else if (elementType == BPRawHTMLTag) {
        // Currently not supported
    } else if (elementType == BPTripleEmphasis) {
        [self renderBoldItalicElement:element toTarget:target];
    } else if (elementType == BPText) {
        [self renderTextElement:element toTarget:target];
    } else if (elementType == BPStrikethrough) {
        [self renderStruckthroughElement:element toTarget:target];
    }
    
    // Render children of this particular element recursively
    
    for (BPElement *childElement in [element childElements]) {
        [self convertElement:childElement toTarget:target];
    }
    
    // Capture the end of the range
    
    effectiveRange.length = [target length] - effectiveRange.location;
    
    // Follow up with some types of block-level elements and apply properties en masse.
    
    if (elementType == BPParagraph) {
        [self renderParagraphElement:element inRange:effectiveRange toTarget:target];
    } else if (elementType == BPHeader) {
        [self renderHeaderElement:element inRange:effectiveRange toTarget:target];
    } else if (elementType == BPListItem) {
        [self renderListItemElement:element inRange:effectiveRange toTarget:target];
    } else if (elementType == BPBlockCode) {
        [self renderBlockCodeElement:element inRange:effectiveRange toTarget:target];
    } else if (elementType == BPBlockQuote) {
        [self renderBlockQuoteElement:element inRange:effectiveRange toTarget:target];
    }
    
    if ([element isBlockElement]
        && ![[element parentElement] isBlockElement]
        && ![[[element parentElement] parentElement] isBlockElement]) {
        [self insertNewlineIntoTarget:target];
    }
}

#pragma mark Character Insertion

- (void)insertNewlineIntoTarget:(NSMutableAttributedString *)target
{
    [target appendAttributedString:[[NSMutableAttributedString alloc] initWithString:@"\n"]];
}

- (void)insertLineSeparatorIntoTarget:(NSMutableAttributedString *)target
{
    if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_8_3) {
        [target appendAttributedString:[[NSMutableAttributedString alloc] initWithString:@"\r"]];
    } else {
        [target appendAttributedString:[[NSMutableAttributedString alloc] initWithString:@"\u2028"]];
    }
}

#pragma mark Span Element Rendering

- (void)renderSpanElement:(BPElement *)element
                 withFont:(UIFont *)font
                 toTarget:(NSMutableAttributedString *)target
{
    [self renderSpanElement:element
                   withFont:font
                 attributes:[NSMutableDictionary dictionary]
                   toTarget:target];
}

- (void)renderSpanElement:(BPElement *)element
                 withFont:(UIFont *)font
               attributes:(NSMutableDictionary *)attributes
                 toTarget:(NSMutableAttributedString *)target
{
  
  if(font == nil)
  {
    NSLog(@"%@", [element debugDescription]);
    return;
  }
  
    attributes[NSFontAttributeName] = font;
    
    NSString *text;
    
    if ([[element parentElement] elementType] == BPBlockCode) {
        
        // Preserve whitespace within a code block
        
        text = [element text];
    } else {
        text = [[element text] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    }

    if (text != nil) {
        NSAttributedString *attributedText = [[NSAttributedString alloc] initWithString:text
                                                                             attributes:attributes];
        [target appendAttributedString:attributedText];
    }
}

- (void)renderTextElement:(BPElement *)element toTarget:(NSMutableAttributedString *)target
{
    if ([_displaySettings defaultColor])
        [self renderSpanElement:element withFont:[_displaySettings defaultFont] attributes:[NSMutableDictionary dictionaryWithDictionary:@{NSForegroundColorAttributeName : [_displaySettings defaultColor]}] toTarget:target];
    else
        [self renderSpanElement:element withFont:[_displaySettings defaultFont] toTarget:target];
    
    if ([_displaySettings defaultFontKerning])
        [target addAttribute:NSKernAttributeName value:[_displaySettings defaultFontKerning] range:NSMakeRange(0, target.length)];
}

- (void)renderBoldItalicElement:(BPElement *)element
                       toTarget:(NSMutableAttributedString *)target
{
    [self renderSpanElement:element withFont:[_displaySettings boldItalicFont] toTarget:target];
}

- (void)renderBoldElement:(BPElement *)element
                 toTarget:(NSMutableAttributedString *)target
{
    if ([_displaySettings boldColor])
        [self renderSpanElement:element withFont:[_displaySettings boldFont] attributes:[NSMutableDictionary dictionaryWithDictionary:@{NSForegroundColorAttributeName : [_displaySettings boldColor]}] toTarget:target];
    else
        [self renderSpanElement:element withFont:[_displaySettings boldFont] toTarget:target];
    
    if ([_displaySettings boldFontKerning])
        [target addAttribute:NSKernAttributeName value:[_displaySettings boldFontKerning] range:NSMakeRange(0, target.length)];
}

- (void)renderItalicElement:(BPElement *)element
                   toTarget:(NSMutableAttributedString *)target
{
    [self renderSpanElement:element withFont:[_displaySettings italicFont] toTarget:target];
}

- (void)renderStruckthroughElement:(BPElement *)element
                          toTarget:(NSMutableAttributedString *)target
{
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    attributes[NSStrikethroughStyleAttributeName] = @(1);
    [self renderSpanElement:element
                   withFont:[_displaySettings defaultFont]
                 attributes:attributes
                   toTarget:target];
}

- (void)renderCodeSpanElement:(BPElement *)element
                     toTarget:(NSMutableAttributedString *)target
{
    [self renderSpanElement:element withFont:[_displaySettings monospaceFont] toTarget:target];
}

- (void)renderLinkElement:(BPElement *)element
                 toTarget:(NSMutableAttributedString *)target
{
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    attributes[NSUnderlineStyleAttributeName] = @(NSUnderlineStyleSingle);
    attributes[NSForegroundColorAttributeName] = [_displaySettings linkColor];
    attributes[BPLinkStyleAttributeName] = element[@"link"];
    [self renderSpanElement:element
                   withFont:[_displaySettings defaultFont]
                 attributes:attributes
                   toTarget:target];
}

- (void)renderLineBreak:(BPElement *)element
               toTarget:(NSMutableAttributedString *)target
{
    [self insertLineSeparatorIntoTarget:target];
}

#pragma mark Block Element Rendering

- (void)renderBlockQuoteElement:(BPElement *)element
                        inRange:(NSRange)effectiveRange
                       toTarget:(NSMutableAttributedString *)target
{
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    attributes[NSFontAttributeName] = [_displaySettings quoteFont];
    attributes[NSForegroundColorAttributeName] = [_displaySettings quoteColor];
    
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    [paragraphStyle setParagraphSpacing:[_displaySettings paragraphSpacingHeading]];
    [paragraphStyle setFirstLineHeadIndent:[_displaySettings quoteIndentation]];
    [paragraphStyle setHeadIndent:[_displaySettings quoteIndentation]];
    [paragraphStyle setTailIndent:-[_displaySettings quoteIndentation]];
    attributes[NSParagraphStyleAttributeName] = paragraphStyle;
    
    [target addAttributes:attributes range:effectiveRange];
}

- (void)renderBlockCodeElement:(BPElement *)element
                       inRange:(NSRange)effectiveRange
                      toTarget:(NSMutableAttributedString *)target
{
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    attributes[NSFontAttributeName] = [_displaySettings monospaceFont];
    attributes[NSForegroundColorAttributeName] = [_displaySettings codeColor];
    
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    [paragraphStyle setParagraphSpacing:[_displaySettings paragraphSpacingCode]];
    [paragraphStyle setFirstLineHeadIndent:[_displaySettings codeIndentation]];
    [paragraphStyle setHeadIndent:[_displaySettings codeIndentation]];
    [paragraphStyle setTailIndent:-[_displaySettings codeIndentation]];
    attributes[NSParagraphStyleAttributeName] = paragraphStyle;
    
    [target addAttributes:attributes range:effectiveRange];
    [self insertNewlineIntoTarget:target];
}

- (void)renderParagraphElement:(BPElement *)element
                       inRange:(NSRange)effectiveRange
                      toTarget:(NSMutableAttributedString *)target
{
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    [paragraphStyle setParagraphSpacing:[_displaySettings paragraphSpacing]];
    [paragraphStyle setLineSpacing:[_displaySettings paragraphLineSpacing]];
    [paragraphStyle setFirstLineHeadIndent:[_displaySettings paragraphFirstLineHeadIndent]];

    if(!self.renderedFirstParagraph) {
        [paragraphStyle setFirstLineHeadIndent:[_displaySettings firstParagraphFirstLineHeadIndent]];
        self.renderedFirstParagraph = true;
    }
    [paragraphStyle setHeadIndent:[_displaySettings paragraphHeadIndent]];

    NSDictionary *attributes = @{NSParagraphStyleAttributeName : paragraphStyle};
    [target addAttributes:attributes range:effectiveRange];
}

- (void)renderListItemElement:(BPElement *)element
                      inRange:(NSRange)effectiveRange
                     toTarget:(NSMutableAttributedString *)target
{
    NSUInteger level = 0;
    BPElement *inspectedElement = [[element parentElement] parentElement];
    NSMutableString *indentation = [NSMutableString  string];
    
    while ([inspectedElement elementType] == BPList
           || [inspectedElement elementType] == BPListItem) {
        if ([inspectedElement elementType] == BPList) {
            [indentation appendString:@"\t"];
            ++level;
        }
        
        inspectedElement = [inspectedElement parentElement];
    }
    
    UIColor *bulletColor;
    
    switch (level % 3) {
        case 1:
            bulletColor = [UIColor grayColor];
            break;
        case 2:
            bulletColor = [UIColor lightGrayColor];
            break;
        default:
            bulletColor = [UIColor blackColor];
            break;
    }
    
    NSDictionary *bulletAttributes = @{
        NSFontAttributeName            : [_displaySettings monospaceFont],
        NSForegroundColorAttributeName : bulletColor
    };
    
    if ([_displaySettings renderBullet])
    {
        NSAttributedString *attributedBullet;
        attributedBullet = [[NSAttributedString alloc] initWithString:@"• "
                                                           attributes:bulletAttributes];
        [target insertAttributedString:attributedBullet atIndex:effectiveRange.location];
    }
    
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    [paragraphStyle setLineSpacing:[_displaySettings lineSpacingSmall]];
    
    NSDictionary *indentationAttributes = @{
        NSFontAttributeName : [UIFont systemFontOfSize:[_displaySettings bulletIndentation]],
        NSParagraphStyleAttributeName : paragraphStyle
    };
    
    NSAttributedString *attributedIndentation;
    attributedIndentation = [[NSAttributedString alloc] initWithString:indentation
                                                            attributes:indentationAttributes];
    [target insertAttributedString:attributedIndentation atIndex:effectiveRange.location];

    if (([[[element parentElement] parentElement] elementType] != BPListItem)
        || (element != [[[element parentElement] childElements] lastObject])) {
        [self insertNewlineIntoTarget:target];
    }
}

- (void)renderHeaderElement:(BPElement *)element
                    inRange:(NSRange)effectiveRange
                   toTarget:(NSMutableAttributedString *)target
{
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    [paragraphStyle setParagraphSpacing:[_displaySettings paragraphSpacingHeading]];
    [paragraphStyle setLineSpacing:[_displaySettings paragraphLineSpacingHeading]];
    [paragraphStyle setFirstLineHeadIndent:[_displaySettings headerFirstLineHeadIndent]];
    [paragraphStyle setHeadIndent:[_displaySettings headerHeadIndent]];
    attributes[NSParagraphStyleAttributeName] = paragraphStyle;
    
    // Override font weight and size attributes (but preserve all other attributes)
    
    switch ([element[@"level"] integerValue]) {
        case 1:
            attributes[NSFontAttributeName] = [_displaySettings h1Font];
            attributes[NSForegroundColorAttributeName] = [_displaySettings h1Color];
            attributes[NSKernAttributeName] = [_displaySettings h1FontKerning];
            break;
        case 2:
            [paragraphStyle setParagraphSpacing:[_displaySettings paragraphSpacingH2]];
            attributes[NSFontAttributeName] = [_displaySettings h2Font];
            attributes[NSForegroundColorAttributeName] = [_displaySettings h2Color];
            attributes[NSKernAttributeName] = [_displaySettings h2FontKerning];
            break;
        case 3:
            attributes[NSFontAttributeName] = [_displaySettings h3Font];
            attributes[NSForegroundColorAttributeName] = [_displaySettings h3Color];
            attributes[NSKernAttributeName] = [_displaySettings h3FontKerning];
            break;
        case 4:
            attributes[NSFontAttributeName] = [_displaySettings h4Font];
            attributes[NSForegroundColorAttributeName] = [_displaySettings h4Color];
            attributes[NSKernAttributeName] = [_displaySettings h4FontKerning];
            break;
        case 5:
            attributes[NSFontAttributeName] = [_displaySettings h5Font];
            attributes[NSForegroundColorAttributeName] = [_displaySettings h5Color];
            attributes[NSKernAttributeName] = [_displaySettings h5FontKerning];
            break;
        case 6:
            attributes[NSFontAttributeName] = [_displaySettings h6Font];
            attributes[NSForegroundColorAttributeName] = [_displaySettings h6Color];
            attributes[NSKernAttributeName] = [_displaySettings h6FontKerning];
            break;
        default:
            attributes[NSFontAttributeName] = [_displaySettings defaultFont];
            attributes[NSForegroundColorAttributeName] = [_displaySettings defaultColor];
            attributes[NSKernAttributeName] = [_displaySettings defaultFontKerning];
            break;
    }
    
    [target addAttributes:attributes range:effectiveRange];
}

@end
