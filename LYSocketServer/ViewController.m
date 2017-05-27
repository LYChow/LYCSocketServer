//
//  ViewController.m
//  LYSocketServer
//
//  Created by hxf on 24/05/2017.
//  Copyright © 2017 sinowave. All rights reserved.
//

#import "ViewController.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <errno.h>


#include <netinet/in.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/wait.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <signal.h>

// for select
#include <sys/select.h>

/*
 ***establishing a socket on the server***
 1.Create a socket with the socket() system call
 2.Bind the socket to an address using the bind() system call. For a server socket on the Internet, an address consists of a port number on the host machine.
 3.Listen for connections with the listen() system call
 4.Accept a connection with the accept() system call. This call typically blocks until a client connects with the server.
 5.Send and receive data
 */

@interface ViewController ()
{
    int client_sock;
    int fd;
}
@property (weak, nonatomic) IBOutlet UITextField *listenerPortTextField;
@property (weak, nonatomic) IBOutlet UITextField *messageBoardTextField;
- (IBAction)startListener:(id)sender;
- (IBAction)sendMessage:(id)sender;
@property (weak, nonatomic) IBOutlet UITextView *messageRecordBoard;



@end

@implementation ViewController


void error(const char *msg)
{
    perror(msg);
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

-(void)asynThread
{
    //1.create socket()
    fd=socket(PF_INET,SOCK_STREAM,0);
    if (fd < 0)
        error("ERROR opening socket");
    
    int on=1;
    int status;
    status = setsockopt(fd,SOL_SOCKET,SO_REUSEADDR,(const char*)&on,sizeof(on));
    
    struct timeval timeout={3,0};//3s
    status=setsockopt(fd,SOL_SOCKET,SO_SNDTIMEO,(const char*)&timeout,sizeof(timeout));
 
    
    struct sockaddr_in server_addr;
    server_addr.sin_family=AF_INET;
    server_addr.sin_port=htons(self.listenerPortTextField.text.integerValue);
    server_addr.sin_addr.s_addr = INADDR_ANY;
    //2.bind()
    if (bind(fd,(struct sockaddr*)&server_addr,sizeof(struct sockaddr)) < 0)
        error("ERROR on binding");
    //3.listen()
    listen(fd, 100);
    
    
    struct sockaddr_in client_addr;
    //4.accept()
    socklen_t client_len = sizeof(client_addr);
    
    
    if((client_sock = accept(fd, (struct sockaddr*)&client_addr, &client_len)) == -1)
    {
        perror("accept error...\n");
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.messageRecordBoard.text = [self.messageRecordBoard.text stringByAppendingString:[NSString stringWithFormat:@"%@ \n",[NSString stringWithCString:"client connected Success!!!" encoding:NSUTF8StringEncoding]]];
        });
        do {
            const char buffer[1024];
            int length = sizeof(buffer);
            int result = recv(client_sock, buffer, length, 0);
            if (result>0)
            {
                const char *buf = buffer;
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.messageRecordBoard.text = [self.messageRecordBoard.text stringByAppendingString:[NSString stringWithFormat:@"%@ \n",[NSString stringWithCString:buf encoding:NSUTF8StringEncoding]]];
                });
            }
        } while (1);
    }

}

#pragma mark -Events
- (IBAction)startListener:(id)sender
{
    NSThread * backgroundThread = [[NSThread alloc] initWithTarget:self
                                                          selector:@selector(epoll)
                                                            object:nil];
    [backgroundThread start];
    
    
    
}


- (IBAction)sendMessage:(id)sender
{
    char buffer[256];
    bzero(buffer, 256);
    //5.send() & receive()
    const char * buf = [self.messageBoardTextField.text UTF8String];
    int ret =send(client_sock, buf, self.messageBoardTextField.text.length,0);
    
}


-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self.view endEditing:YES];
}

-(void)epoll
{
    
    fd=socket(PF_INET,SOCK_STREAM,0);
    if (fd < 0)
        error("ERROR opening socket");
    
    int on=1;
    int status;
    status = setsockopt(fd,SOL_SOCKET,SO_REUSEADDR,(const char*)&on,sizeof(on));
    
//    struct timeval timeout={3,0};//3s
//    status=setsockopt(fd,SOL_SOCKET,SO_SNDTIMEO,(const char*)&timeout,sizeof(timeout));
    
    
    struct sockaddr_in server_addr;
    server_addr.sin_family=AF_INET;
    server_addr.sin_port=htons(self.listenerPortTextField.text.integerValue);
    server_addr.sin_addr.s_addr = INADDR_ANY;
    //2.bind()
    if (bind(fd,(struct sockaddr*)&server_addr,sizeof(struct sockaddr)) < 0)
        error("ERROR on binding");
    //3.listen()
    listen(fd, 100);
    
    
    fd_set rfd;                     // 描述符集 这个将用来测试有没有一个可用的连接
    FD_ZERO(&rfd);                      //总是这样先清空一个描述符集
    
    
    FD_SET(fd,&rfd);
    
    int ret =select(fd+1,&rfd,NULL,NULL,NULL); //timeout>0等待超时的时间(超时返回0时做一个处理);timeout=0为非阻塞;timeout=NULL时为阻塞
    if(ret>0)
    {
        do
        {
            if(FD_ISSET(fd,&rfd))
            {
                struct sockaddr_in client_addr;
                //4.accept()
                socklen_t client_len = sizeof(client_addr);
                
                //每次收到Accept开启一个新的线程
                if((client_sock = accept(fd, (struct sockaddr*)&client_addr, &client_len)) != -1)
                {
                    NSString *connectSuccess = [NSString stringWithFormat:@"client connect success,from client:%d",client_sock];
                    dispatch_async(dispatch_get_main_queue(), ^{
                self.messageRecordBoard.text = [self.messageRecordBoard.text stringByAppendingString:[NSString stringWithFormat:@"%@ \n",[NSString stringWithCString:[connectSuccess UTF8String] encoding:NSUTF8StringEncoding]]];
                                                            });
                    
                    
                    NSThread * backgroundThread = [[NSThread alloc] initWithTarget:self
                                                                          selector:@selector(newClientConnected:)
                                                                            object:@(client_sock)];
                    [backgroundThread start];
//                    FD_ZERO(&rfd);
//                    FD_SET(client_sock,&rfd);
//                    do {
//                        if(select(client_sock+1,&rfd,NULL,0,NULL)>0)
//                        {
//                            if(FD_ISSET(client_sock,&rfd))   //client_sock可读
//                            {
//                                
//                                const char buffer[1024];
//                                int length = sizeof(buffer);
//                                int result = recv(client_sock, buffer, length, 0);
//                                if (result>0)
//                                {
//                                    const char *buf = buffer;
//                                    dispatch_async(dispatch_get_main_queue(), ^{
//                                        self.messageRecordBoard.text = [self.messageRecordBoard.text stringByAppendingString:[NSString stringWithFormat:@"%@ \n",[NSString stringWithCString:buf encoding:NSUTF8StringEncoding]]];
//                                    });
//                                }
//                            }
//                        }
//                    } while (1);
                }
            }
        } while (1);
        
    }
    
}

-(void)newClientConnected:(nullable id)argument
{
    int sock = [argument intValue];
    fd_set rfd;                     // 描述符集 这个将用来测试有没有一个可用的连接
    FD_ZERO(&rfd);
    FD_SET(sock,&rfd);
    do {
        if(select(sock+1,&rfd,NULL,0,NULL)>0)
        {
            if(FD_ISSET(sock,&rfd))   //client_sock可读
            {
                
                const char buffer[1024];
                int length = sizeof(buffer);
                int result = recv(sock, buffer, length, 0);
                if (result>0)
                {
                    const char *buf = buffer;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.messageRecordBoard.text = [self.messageRecordBoard.text stringByAppendingString:[NSString stringWithFormat:@"%@ \n",[NSString stringWithCString:buf encoding:NSUTF8StringEncoding]]];
                    });
                }
            }
        }
    } while (1);
    
}

//-(void)epoll
//{
//    struct sockaddr_in client_addr;
//    //  values for select
//    int             maxfd;
//    fd_set          rset, allset;
//    struct  timeval timeout;
//
//
//    //  initial "select" elements
//    maxfd  = fd;                     //新增listenfd，所以更新当前的最大fd
//    //  allret用于保存清楚完标志的fd_ret信息, 在每次处理完后，赋值给rset
//    FD_ZERO(&allset);
//    FD_SET(fd, &allset);
//    
//
//    rset = allset;   //rset和allset的搭配使得新加入的fd要等到下次select才会被监听
//        
//        //  如果有timeout设置，那么每次select之前都要再重新设置一下timeout的值
//        //  因为select会修改timeout的值。
//        timeout.tv_sec = 0;
//        timeout.tv_usec = 500000;
//        
//        
//        if((select(maxfd + 1, &rset, (fd_set *)NULL, (fd_set *)NULL, &timeout)) < 0) //一开始select监听的是监听口
//        {
//            //  如果有timeout设置，那么每次select之前都要再重新设置一下timeout的值
//            //  因为select会修改timeout的值。
//            perror("select error...\n");
//            exit(-1);
//        }
//        
//        //  接收到数据请求后, 检测数据请求的套接字来自那些套接字
//        //
//        //  首先检测服务器监听套接字有没有数据，
//        //  如果有的话说明监听到了客户端的，
//        //  应该调用accept来获取客户端的连接
//        //
//        //  接着检测客户端的连接套接字有没有数据连接
//        //  如果有的话，说明客户端跟服务器有通信请求
//        
//        //  首先检测服务器监听套接字有没有数据
//        
//        if(FD_ISSET(fd, &rset))   //  测试socketFd有没有消息
//        {
//            //4.accept()
//            socklen_t client_len = sizeof(client_addr);
//            
//            
//            if((client_sock = accept(fd, (struct sockaddr*)&client_addr, &client_len)) == -1)
//            {
//                perror("accept error...\n");
//            }
//            
//            
//            //  新加入的描述符，还没判断是否可以或者写
//            //  将缓存的allset的对应connfd置位，下次循环时即可监听connfd
//            FD_SET(client_sock, &allset);
//            if (client_sock > maxfd)  //  maxfd是为了下次select，作为参数使用
//            {
//                maxfd = client_sock;
//            }
//            //  至此监听套接字的信息已经被处理, 应该先清楚对应位
//            FD_CLR(fd, &rset);
//            
//        }
//        
//        
//        //  遍历套接字看那些客户端连接套接字有数据请求
//        for(int listendfd = 0;listendfd <= maxfd;listendfd++)
//        {
//            if(FD_ISSET(listendfd, &rset))         //  检测到客户端连接套接字fd有数据请求
//            {
//                
//                char buffer[256];
//                bzero(buffer,256);
//                //                ret = read(client_sock,buffer,255);
//                recv(client_sock, buffer, 255, 0);
//                const char *buf = buffer;
//               printf("%s",buf);
//                //  清楚allset的对应位，以备fd可被继续select监听
//                FD_CLR(fd, &allset);//清除，表示已被处理
//                
//            }
//        }
//    }



@end
