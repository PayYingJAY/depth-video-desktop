using System;
using System.IO;
using System.Text;
using System.Linq;
using System.Drawing;
using System.Diagnostics;
using System.Threading.Tasks;
using System.Collections.Generic;
using System.Web.Script.Serialization;
using System.Text.RegularExpressions;
using System.Windows.Forms;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

class DepthWindow : Form {
    readonly string root=AppDomain.CurrentDomain.BaseDirectory;
    readonly string data=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"DepthVideoDesktop");
    readonly JavaScriptSerializer json=new JavaScriptSerializer();
    readonly WebView2 web=new WebView2();
    readonly object logLock=new object();
    string input="", output="", inputUrl="", resultUrl="", summary="", status="准备就绪", detail="选择视频，然后点击「开始处理」", elapsed="", log="";
    bool busy=false, cancelling=false, closing=false;
    int progress=0;
    Process child;
    string launchInput="";
    Stopwatch watch=new Stopwatch();
    string Engine { get { return Path.Combine(root,"engine"); } }
    string RuntimeDir { get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"DV","r1"); } }
    string Runtime { get { return Path.Combine(RuntimeDir,"python.exe"); } }
    string Page { get { return new Uri(Path.Combine(root,"ui","index.html")).AbsoluteUri; } }
    public DepthWindow(string file) {
        launchInput=file;
        Text="深度视频"; Size=new Size(1160,820); MinimumSize=new Size(880,650); StartPosition=FormStartPosition.CenterScreen;
        AutoScaleMode=AutoScaleMode.Dpi; web.Dock=DockStyle.Fill; Controls.Add(web);
        Directory.CreateDirectory(data); log=Path.Combine(data,"desktop.log");
        Load+=async delegate { await Initialize(); };
        FormClosing+=delegate(object sender,FormClosingEventArgs e){
            if(busy&&!closing){e.Cancel=true;if(MessageBox.Show(this,"视频仍在处理中，停止处理并退出？","退出",MessageBoxButtons.YesNo,MessageBoxIcon.Question)==DialogResult.Yes){closing=true;Cancel();}}
        };
    }
    async Task Initialize(){
        try {
            var env=await CoreWebView2Environment.CreateAsync(null,Path.Combine(data,"webview"));
            await web.EnsureCoreWebView2Async(env);
            web.CoreWebView2.Settings.AreDefaultContextMenusEnabled=false;
            web.CoreWebView2.Settings.AreDevToolsEnabled=false;
            web.CoreWebView2.Settings.IsStatusBarEnabled=false;
            web.CoreWebView2.NavigationStarting+=delegate(object s,CoreWebView2NavigationStartingEventArgs e){if(!String.Equals(e.Uri,Page,StringComparison.OrdinalIgnoreCase))e.Cancel=true;};
            web.CoreWebView2.NewWindowRequested+=delegate(object s,CoreWebView2NewWindowRequestedEventArgs e){e.Handled=true;};
            web.CoreWebView2.PermissionRequested+=delegate(object s,CoreWebView2PermissionRequestedEventArgs e){e.State=CoreWebView2PermissionState.Deny;};
            web.CoreWebView2.WebMessageReceived+=async delegate(object s,CoreWebView2WebMessageReceivedEventArgs e){
                if(!String.Equals(e.Source,Page,StringComparison.OrdinalIgnoreCase))return;
                try {
                    var m=json.Deserialize<Dictionary<string,object>>(e.WebMessageAsJson);
                    string action=Convert.ToString(m["action"]);
                    if(action=="pick"&&!busy)Pick();
                    else if(action=="start"&&!busy)await Run(Convert.ToString(m["fps"])=="0"?"0":"15");
                    else if(action=="cancel"&&busy)Cancel();
                    else if(action=="folder"&&File.Exists(output))Process.Start("explorer.exe",Quote(Path.GetDirectoryName(output)));
                    else if(action=="logs"){if(!File.Exists(log))File.WriteAllText(log,"尚无处理记录。",Encoding.UTF8);Process.Start("notepad.exe",Quote(log));}
                    else if(action=="ready"){if(File.Exists(launchInput)){SelectFile(Path.GetFullPath(launchInput));launchInput="";}else Publish();}
                }catch(Exception ex){Fail(ex);}
            };
            web.Source=new Uri(Page);
        }catch(Exception ex){
            MessageBox.Show(this,"界面启动失败。请确认电脑已安装 Microsoft Edge WebView2 运行时。\n\n"+ex.Message,"无法启动",MessageBoxButtons.OK,MessageBoxIcon.Error);
            Close();
        }
    }
    static string Quote(string value){return "\""+value.Replace("\"", "\\\"")+"\"";}
    void Pick(){
        using(var dialog=new OpenFileDialog()){
            dialog.Title="选择要处理的视频"; dialog.Filter="视频文件|*.mp4;*.mov;*.mkv;*.avi;*.webm;*.m4v|所有文件|*.*";
            if(dialog.ShowDialog(this)!=DialogResult.OK)return;
            SelectFile(dialog.FileName);
        }
    }
    void SelectFile(string file){
        input=file; output=""; resultUrl=""; summary=""; elapsed=""; progress=0;
        inputUrl=Map("input",input); status="可以开始处理";detail="快速模式适合先看效果；需要更连贯的动作可保留原帧率。";Publish();
    }
    string Map(string prefix,string file){
        return new Uri(Path.GetFullPath(file)).AbsoluteUri;
    }
    async void Publish(){
        if(IsDisposed||web.CoreWebView2==null)return;
        var state=new {filename=Path.GetFileName(input), inputUrl=inputUrl,resultUrl=resultUrl,summary=summary,status=status,detail=detail,progress=progress,busy=busy,cancelling=cancelling,elapsed=elapsed};
        try {await web.ExecuteScriptAsync("window.desktopState && window.desktopState("+json.Serialize(state)+")");}catch(ObjectDisposedException){}catch(InvalidOperationException){}
    }
    void WriteLog(string line){lock(logLock){File.AppendAllText(log,DateTime.Now.ToString("HH:mm:ss ")+line+Environment.NewLine,Encoding.UTF8);}}
    void OnLine(string line,bool setup){
        WriteLog(line);
        if(IsDisposed||!IsHandleCreated)return;
        BeginInvoke((Action)delegate{
            if(!busy||cancelling)return;
            if(setup){detail="首次准备可能需要几分钟，完成后自动开始。可查看日志了解下载进度。";}
            else {
                var match=Regex.Match(line,@"(\d{1,3})%\|");
                if(match.Success){progress=Math.Min(94,10+(int)(int.Parse(match.Groups[1].Value)*.84));status="正在生成深度画面";detail="逐帧分析中，完成后自动导出视频。";}
                if(line.Contains("inference frames")){progress=10;status="正在生成深度画面";}
                if(line.StartsWith("COMPLETE:")){progress=99;status="正在检查结果";}
            }
            Publish();
        });
    }
    async Task<int> Execute(string exe,string args,bool setup){
        var info=new ProcessStartInfo(exe,args){WorkingDirectory=Engine,UseShellExecute=false,CreateNoWindow=true,RedirectStandardOutput=true,RedirectStandardError=true,StandardOutputEncoding=Encoding.UTF8,StandardErrorEncoding=Encoding.UTF8};
        info.EnvironmentVariables["PYTHONUTF8"]="1";info.EnvironmentVariables["PYTHONIOENCODING"]="utf-8";info.EnvironmentVariables["PYTHONNOUSERSITE"]="1";
        info.EnvironmentVariables["DEPTHVIDEO_RUNTIME_DIR"]=RuntimeDir;
        child=new Process {StartInfo=info};
        child.OutputDataReceived+=delegate(object s,DataReceivedEventArgs e){if(e.Data!=null)OnLine(e.Data,setup);};
        child.ErrorDataReceived+=delegate(object s,DataReceivedEventArgs e){if(e.Data!=null)OnLine(e.Data,setup);};
        child.Start();child.BeginOutputReadLine();child.BeginErrorReadLine();
        Process active=child;
        await Task.Run(delegate{active.WaitForExit();});
        int code=active.ExitCode;active.Dispose();child=null;return code;
    }
    async Task Run(string fps){
        if(!File.Exists(input)){status="找不到原视频";detail="文件可能已移动，请重新选择。";Publish();return;}
        busy=true;cancelling=false;resultUrl="";output="";summary="";elapsed="";progress=-1;watch.Restart();
        try {
            WriteLog("START "+input+" fps="+fps);
            if(RuntimeDir.Length>70)throw new Exception("当前用户目录过长，无法安全安装运行环境。请联系提供者调整环境目录；无需更改系统长路径设置。");
            string marker=Path.Combine(RuntimeDir,"depthvideo-v1-isolated.ready");
            if(!File.Exists(Runtime)||!File.Exists(marker)){
                status="正在准备运行环境";detail="首次联网下载，视频不会上传。准备完成后将自动开始。";Publish();
                int setup=await Execute("powershell.exe","-NoProfile -ExecutionPolicy Bypass -File "+Quote(Path.Combine(Engine,"run.ps1"))+" -SetupOnly -ChinaMirror",true);
                if(cancelling)return;
                if(setup!=0)throw new Exception("运行环境准备失败。可能与下载、磁盘空间或系统依赖有关，请点击「查看日志」查看具体原因后重试。");
            }
            if(cancelling)return;
            status="正在读取视频";detail="加载模型与视频，随后开始生成深度画面。";progress=-1;Publish();
            string resultRoot=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyVideos),"深度视频");
            string job=Path.Combine(resultRoot,DateTime.Now.ToString("yyyyMMdd_HHmmss")+"_"+Guid.NewGuid().ToString("N").Substring(0,6));
            Directory.CreateDirectory(job);
            int code=await Execute(Runtime,"-s -u "+Quote(Path.Combine(Engine,"depth_video.py"))+" "+Quote(input)+" --output "+Quote(job)+" --fps "+fps,false);
            if(cancelling)return;
            if(code!=0)throw new Exception("处理未完成。可尝试快速模式或较短视频；点击「查看日志」查看具体原因。");
            var reports=Directory.GetFiles(job,"*.json");
            if(reports.Length!=1)throw new Exception("未找到完整的结果报告，请查看日志。");
            var report=json.Deserialize<Dictionary<string,object>>(File.ReadAllText(reports[0],Encoding.UTF8));
            output=Convert.ToString(report["output"]);
            if(!File.Exists(output))throw new Exception("结果文件缺失，请重新处理。");
            resultUrl=Map("result",output);summary=String.Format("深度结果 · {0:0.#} 秒 · {1:0.#} 帧/秒",Convert.ToDouble(report["output_duration"]),Convert.ToDouble(report["output_fps"]));
            progress=100;status="处理完成";detail="结果已保存到「视频 / 深度视频」，可直接预览或打开文件夹。";
        }catch(Exception ex){Fail(ex);}
        finally {
            watch.Stop();elapsed="用时 "+watch.Elapsed.TotalSeconds.ToString("0.0")+" 秒";busy=false;
            if(cancelling){status="已取消";detail="原视频未修改，可以重新开始。";progress=0;}
            cancelling=false;Publish();if(closing)Close();
        }
    }
    async void Cancel(){
        if(cancelling)return;cancelling=true;status="正在停止处理";detail="正在关闭处理进程，请稍候。";Publish();
        Process active=child;
        if(active!=null){
            try {
                int pid=active.Id;
                await Task.Run(delegate{using(var kill=Process.Start(new ProcessStartInfo("taskkill.exe","/PID "+pid+" /T /F"){UseShellExecute=false,CreateNoWindow=true,RedirectStandardOutput=true,RedirectStandardError=true})){kill.WaitForExit();}});
            }catch(InvalidOperationException){}catch(Exception ex){WriteLog("Cancel: "+ex.Message);}
        }
    }
    void Fail(Exception ex){WriteLog(ex.ToString());status="遇到问题";detail=ex.Message;progress=0;Publish();}
    [STAThread] static void Main(string[] args){
        bool created;
        using(var mutex=new System.Threading.Mutex(true,"Local\\DepthVideoDesktopV1",out created)){
            if(!created){MessageBox.Show("深度视频已经打开，请使用已有窗口。");return;}
            Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);Application.Run(new DepthWindow(args.Length>0?args[0]:""));
        }
    }
}
