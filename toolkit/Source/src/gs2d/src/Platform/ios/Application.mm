#import "Application.h"

#import "../NativeCommandManager.h"

#import <Video.h>
#import <Audio.h>
#import <Input.h>

#import <BaseApplication.h>

#import <Platform/ios/IOSFileIOHub.h>

#import <Input/iOS/IOSInput.h>

@interface ApplicationWrapper ()
{
	gs2d::VideoPtr m_video;
	gs2d::InputPtr m_input;
	gs2d::AudioPtr m_audio;
	gs2d::BaseApplicationPtr m_engine;
	float m_pixelDensity;
	Platform::NativeCommandManager m_commandManager;
}

@property (strong, nonatomic) NSMutableArray* touches;
@property (strong, nonatomic) NSLock* arrayLock;

- (void)start:(GLKView*) view;
- (void)restore;

@end

@implementation ApplicationWrapper

- (id)init
{
	self = [super init];

	if (self)
	{
		m_pixelDensity = 1.0f;
	}

	self.touches   = [[NSMutableArray alloc] init];
	self.arrayLock = [[NSLock alloc] init];

	// setup default subplatform
	gs2d::Application::SharedData.Create("com.ethanonengine.subplatform", "apple", true  /*constant*/);

	NSString* appVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
	gs2d::Application::SharedData.Create("com.ethanonengine.versionName", [appVersionString UTF8String], true  /*constant*/);

	// setup language code
	NSString *language = [[NSLocale preferredLanguages] objectAtIndex:0];
	NSRange designatorRange = NSMakeRange(0, 2);
	language = [language substringWithRange:designatorRange];
	gs2d::Application::SharedData.Create("ethanon.system.language", [language cStringUsingEncoding:1], false /*constant*/);
	
	return self;
}

- (void)start:(GLKView*) view
{
	m_audio = gs2d::CreateAudio(0);
	m_input = gs2d::CreateInput(false);

	Platform::FileIOHubPtr fileIOHub(new Platform::IOSFileIOHub("data/"));

	const gs2d::math::Vector2 size = gs2d::math::Vector2(view.drawableWidth, view.drawableHeight);
	m_video = gs2d::CreateVideo(static_cast<unsigned int>(size.x), static_cast<unsigned int>(size.y), fileIOHub);

	m_engine = gs2d::CreateBaseApplication();
	m_engine->Start(m_video, m_input, m_audio);

	m_pixelDensity = [view contentScaleFactor];
	
	m_commandManager.InsertCommandListener(Platform::IOSNativeCommmandListenerPtr(new Platform::IOSNativeCommmandListener));
}

- (void)update
{
	@try
	{
		if (!m_engine) return;

		m_input->Update();
		m_audio->Update();

		const float elapsedTime = (gs2d::ComputeElapsedTimeF(m_video));
		m_engine->Update(gs2d::math::Min(400.0f, elapsedTime));
		
		m_commandManager.RunCommands(m_video->PullCommands());
	}
	@catch (NSException *exception)
	{
		NSLog([exception reason]);
	}
}

- (void)renderFrame:(GLKView*) view;
{
	if (!m_engine)
	{
		[self start:view];
		glClearColor(1.0f, 1.0f, 1.0f, 1.0f);
		glClear(GL_DEPTH_BUFFER_BIT | GL_COLOR_BUFFER_BIT);
	}
	else
	{
		m_engine->RenderFrame();
	}
}

- (void)destroy
{
	m_engine->Destroy();
}

- (void)restore
{
	if (m_engine)
	{
		m_engine->Restore();
	}
}

- (void)detectJoysticks
{
	if (m_input)
	{
		m_input->DetectJoysticks();
	}
}

- (void)forceGamepadPause
{
	gs2d::IOSInput* input = static_cast<gs2d::IOSInput*>(m_input.get());
	if (input)
	{
		input->ForceGamepadPause();
	}
}

- (void)touchesBegan:(UIView*) thisView withTouches:(NSSet*) touches withEvent:(UIEvent*) event
{
	[self.arrayLock lock];
	gs2d::IOSInput* input = static_cast<gs2d::IOSInput*>(m_input.get());

	for (UITouch *touch in touches)
	{
		unsigned int touchIdx = 0;
		bool added = false;

		NSUInteger count = [self.touches count];
		for (NSUInteger ui = 0; ui < count; ui++)
		{
			id storedTouch = [self.touches objectAtIndex:ui];
			if (storedTouch == nil || storedTouch == [NSNull null])
			{
				touchIdx = static_cast<unsigned int>(ui);
				[self.touches setObject:touch atIndexedSubscript:ui];
				added = true;
				break;
			}
		}

		if (!added)
		{
			touchIdx = static_cast<unsigned int>(count);
			[self.touches addObject:touch];
			added = true;
		}

		CGPoint location = [touch locationInView:thisView];
		input->SetCurrentTouchPos(touchIdx++, gs2d::math::Vector2(location.x, location.y) * m_pixelDensity);
	}
	[self.arrayLock unlock];
}

- (void)touchesMoved:(UIView*) thisView withTouches:(NSSet*) touches withEvent:(UIEvent*) event
{
	[self.arrayLock lock];
	gs2d::IOSInput* input = static_cast<gs2d::IOSInput*>(m_input.get());
	for (UITouch *touch in touches)
	{
		NSUInteger touchIdx = [self.touches indexOfObject:touch];

		if (touchIdx != NSNotFound)
		{
			CGPoint location = [touch locationInView:thisView];
			input->SetCurrentTouchPos(
				static_cast<unsigned int>(touchIdx),
				gs2d::math::Vector2(location.x, location.y) * m_pixelDensity);
		}
		else
		{
			NSLog(@"TouchMoved touch not found!");
		}
	}
	[self.arrayLock unlock];
}

- (void)touchesEnded:(UIView*) thisView withTouches:(NSSet*) touches withEvent:(UIEvent*) event
{
	[self.arrayLock lock];
	gs2d::IOSInput* input = static_cast<gs2d::IOSInput*>(m_input.get());
	for (UITouch *touch in touches)
	{
		NSUInteger touchIdx = [self.touches indexOfObject:touch];
		if (touchIdx != NSNotFound)
			[self.touches setObject:[NSNull null] atIndexedSubscript:touchIdx];
		if (touchIdx != NSNotFound)
		{
			input->SetCurrentTouchPos(static_cast<unsigned int>(touchIdx), gs2d::GS_NO_TOUCH);
		}
		else
		{
			NSLog(@"TouchEnded touch not found!");
		}
	}
	[self.arrayLock unlock];
}

- (void)touchesCancelled:(UIView*) thisView withTouches:(NSSet*) touches withEvent:(UIEvent*) event
{
	[self touchesEnded:thisView withTouches:touches withEvent:event];
}

- (void)insertCommandListener:(const Platform::NativeCommandListenerPtr) listener
{
	m_commandManager.InsertCommandListener(listener);
}

- (void)updateAccelerometer:(CMAccelerometerData*) accelerometerData
{
	gs2d::IOSInput* input = static_cast<gs2d::IOSInput*>(m_input.get());
	input->SetAccelerometerData(gs2d::math::Vector3(
		static_cast<float>(accelerometerData.acceleration.x),
		static_cast<float>(accelerometerData.acceleration.y),
		static_cast<float>(accelerometerData.acceleration.z)));
}

@end
