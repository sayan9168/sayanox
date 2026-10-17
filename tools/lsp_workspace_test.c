/* Real framed sessions, including filesystem mutation between answered queries.
 * POSIX C + the built server only; no interpreter, socket, or timing sleeps. */
#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <signal.h>
#include <assert.h>
static FILE *input,*output;
static pid_t child;
static char response[4*1024*1024];
static void start(const char *bin) {
    int in[2],out[2]; assert(!pipe(in)&&!pipe(out));
    child=fork(); assert(child>=0);
    if(!child) {
        dup2(in[0],0); dup2(out[1],1);
        close(in[0]);close(in[1]);close(out[0]);close(out[1]);
        execl(bin,bin,(char*)NULL); _exit(127);
    }
    close(in[0]);close(out[1]);
    input=fdopen(in[1],"w");output=fdopen(out[0],"r");assert(input&&output);
}
static void send_msg(const char *body) {
    fprintf(input,"Content-Length: %zu\r\n\r\n%s",strlen(body),body);fflush(input);
}
static const char *answer(int id) {
    char key[64],line[256];snprintf(key,sizeof key,"\"id\":%d,",id);
    for(;;) {
        size_t length=0;
        assert(fgets(line,sizeof line,output));
        assert(sscanf(line,"Content-Length: %zu",&length)==1);
        assert(fgets(line,sizeof line,output));
        assert(!strcmp(line,"\r\n")||!strcmp(line,"\n"));
        assert(length<sizeof response);
        assert(fread(response,1,length,output)==length);response[length]=0;
        if(strstr(response,key)) return response;
    }
}
static void request(int id,const char *method,const char *params) {
    char body[32768];
    int n=snprintf(body,sizeof body,"{\"jsonrpc\":\"2.0\",\"id\":%d,\"method\":\"%s\",\"params\":%s}",id,method,params);
    assert(n>0&&(size_t)n<sizeof body);send_msg(body);answer(id);
    assert(!strstr(response,"\"error\":"));
}
static void stop(void) {
    send_msg("{\"jsonrpc\":\"2.0\",\"method\":\"exit\"}");
    fclose(input);fclose(output);int status;assert(waitpid(child,&status,0)==child);
    assert(WIFEXITED(status)&&WEXITSTATUS(status)==0);
}
static void uri(const char *path,char *out,size_t size) {
    const char *hex="0123456789ABCDEF";size_t n=7;assert(size>8);memcpy(out,"file://",7);
    for(const unsigned char *p=(const unsigned char*)path;*p;p++) {
        unsigned char c=*p;assert(n+4<size);
        if((c>='a'&&c<='z')||(c>='A'&&c<='Z')||(c>='0'&&c<='9')||strchr("/-._~",c)) out[n++]=(char)c;
        else {out[n++]='%';out[n++]=hex[c>>4];out[n++]=hex[c&15];}
    }out[n]=0;
}
static void write_text(const char *path,const char *text) {
    FILE *f=fopen(path,"w");assert(f);assert(fputs(text,f)>=0);assert(!fclose(f));
}
static int count(const char *s,const char *needle) {
    int n=0;for(const char *p=s;(p=strstr(p,needle));p+=strlen(needle))n++;return n;
}
int main(int argc,char **argv) {
    assert(argc==3);alarm(120);
    char path[4096],root[12288],a[12288],b[12288],params[30000];
    uri(argv[2],root,sizeof root);
    snprintf(path,sizeof path,"%s/a.sa",argv[2]);
    write_text(path,"make folder_func(x: num) -> num {\n  give x\n}\nshow folder_func(1)\n");uri(path,a,sizeof a);
    snprintf(path,sizeof path,"%s/sub dir",argv[2]);assert(!mkdir(path,0700));
    snprintf(path,sizeof path,"%s/sub dir/b.sa",argv[2]);write_text(path,"show folder_func(2)\n");uri(path,b,sizeof b);
    for(int i=0;i<6;i++) {
        snprintf(path,sizeof path,"%s/unopened%d.sa",argv[2],i);
        char text[80];snprintf(text,sizeof text,"hold unopened%d = %d\n",i,i);write_text(path,text);
    }
    snprintf(path,sizeof path,"%s/.git",argv[2]);assert(!mkdir(path,0700));
    snprintf(path,sizeof path,"%s/.git/ignored.sa",argv[2]);write_text(path,"hold hidden_symbol = 1\n");
    snprintf(path,sizeof path,"%s/loop",argv[2]);assert(!symlink(argv[2],path));
    snprintf(path,sizeof path,"%s/linked.sa",argv[2]);assert(!symlink("a.sa",path));
    snprintf(path,sizeof path,"%s/large.sa",argv[2]);
    FILE *big=fopen(path,"w");assert(big);for(int i=0;i<270000;i++)fputc(' ',big);fputs("\nhold oversized_symbol = 1\n",big);fclose(big);
    start(argv[1]);
    snprintf(params,sizeof params,"{\"rootUri\":\"%s\"}",root);request(1,"initialize",params);
    request(2,"workspace/symbol","{\"query\":\"FOLDER\"}");
    assert(strstr(response,"folder_func")&&strstr(response,a));
    request(3,"workspace/symbol","{\"query\":\"unopened\"}");
    assert(count(response,"\"name\":")==6);
    request(4,"workspace/symbol","{\"query\":\"symbol\"}");assert(strstr(response,"\"result\":[]"));
    snprintf(params,sizeof params,"{\"textDocument\":{\"uri\":\"%s\"},\"position\":{\"line\":0,\"character\":6},\"context\":{\"includeDeclaration\":false}}",b);
    request(5,"textDocument/references",params);
    assert(count(response,"\"uri\":")==2&&strstr(response,a)&&strstr(response,b));
    assert(strstr(response,"\"character\":5")&&strstr(response,"\"character\":16"));
    char include_params[30000];snprintf(include_params,sizeof include_params,"{\"textDocument\":{\"uri\":\"%s\"},\"position\":{\"line\":0,\"character\":6},\"context\":{\"includeDeclaration\":true}}",b);
    request(50,"textDocument/references",include_params);assert(count(response,"\"uri\":")==3);
    printf("workspace unopened symbols and references; encoded paths; more than four disk files\n");
    char body[30000];snprintf(body,sizeof body,"{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didOpen\",\"params\":{\"textDocument\":{\"uri\":\"%s\",\"text\":\"hold overlay_only = 1\\nshow folder_func(9)\\n\"}}}",a);send_msg(body);
    request(6,"workspace/symbol","{\"query\":\"folder_func\"}");assert(strstr(response,"\"result\":[]"));
    request(7,"workspace/symbol","{\"query\":\"overlay\"}");assert(count(response,"overlay_only")==1);
    request(8,"textDocument/references",params);assert(count(response,"\"uri\":")==2);
    snprintf(body,sizeof body,"{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didClose\",\"params\":{\"textDocument\":{\"uri\":\"%s\"}}}",a);send_msg(body);
    request(9,"workspace/symbol","{\"query\":\"folder_func\"}");assert(count(response,"folder_func")==1);
    snprintf(path,sizeof path,"%s/sub dir/b.sa",argv[2]);write_text(path,"hold disk_changed = 3\n");
    request(10,"workspace/symbol","{\"query\":\"disk_changed\"}");assert(strstr(response,b));
    assert(!unlink(path));request(11,"workspace/symbol","{\"query\":\"disk_changed\"}");assert(strstr(response,"\"result\":[]"));
    printf("workspace open overlay deduplicates; close restores disk; disk edits/deletes refresh\n");
    stop();
    // Root selection through first workspaceFolders URI; invalid/nonlocal roots
    // stay empty and must not prevent later requests in the same session.
    start(argv[1]);snprintf(params,sizeof params,"{\"workspaceFolders\":[{\"uri\":\"%s\",\"name\":\"root\"}]}",root);
    request(1,"initialize",params);request(2,"workspace/symbol","{\"query\":\"folder_func\"}");assert(strstr(response,a));stop();
    const char *bad[]={"https://registry.invalid/root","file:///bad%00root","file:///bad%QZroot","file://remote.invalid/root","file:///does-not-exist-sayanox"};
    for(size_t i=0;i<sizeof bad/sizeof *bad;i++) {
        start(argv[1]);snprintf(params,sizeof params,"{\"rootUri\":\"%s\"}",bad[i]);request(1,"initialize",params);
        request(2,"workspace/symbol","{\"query\":\"\"}");assert(strstr(response,"\"result\":[]"));request(3,"shutdown","{}");stop();
    }
    printf("workspace first folder; symlinks/hidden/oversized skipped; invalid/nonlocal roots stay responsive\n");
    // The file cap is an actual enforced bound, not an open-buffer claim.
    snprintf(path,sizeof path,"%s/cap",argv[2]);assert(!mkdir(path,0700));char cap[2048];size_t caplen=strlen(path);assert(caplen<sizeof cap);memcpy(cap,path,caplen+1);
    for(int i=0;i<140;i++){snprintf(path,sizeof path,"%s/f%03d.sa",cap,i);write_text(path,"hold capped = 1\n");}
    uri(cap,root,sizeof root);start(argv[1]);snprintf(params,sizeof params,"{\"rootUri\":\"%s\"}",root);request(1,"initialize",params);
    request(2,"workspace/symbol","{\"query\":\"capped\"}");assert(count(response,"\"name\":")==128);stop();
    printf("workspace 128-file cap enforced\n");
    return 0;
}
