#!/usr/bin/env python3
"""
prplOS Patch Management Monitoring Dashboard
Real-time monitoring and analysis of patch application performance
"""

import os
import sys
import json
import time
import subprocess
import argparse
from datetime import datetime
from collections import defaultdict
import threading
import queue

# Check for required packages
try:
    import matplotlib.pyplot as plt
    import pandas as pd
    import numpy as np
    from matplotlib.animation import FuncAnimation
    import seaborn as sns
except ImportError:
    print("Installing required packages...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", 
                          "matplotlib", "pandas", "numpy", "seaborn"])
    import matplotlib.pyplot as plt
    import pandas as pd
    import numpy as np
    from matplotlib.animation import FuncAnimation
    import seaborn as sns

class PatchMonitorDashboard:
    """Real-time monitoring dashboard for prplOS patch management"""
    
    def __init__(self, results_dir="/tmp/patch_results", update_interval=1000):
        self.results_dir = results_dir
        self.update_interval = update_interval
        self.data_queue = queue.Queue()
        self.monitoring = True
        
        # Data storage
        self.system_metrics = {
            'timestamp': [],
            'cpu_usage': [],
            'memory_usage': [],
            'disk_io': [],
            'network_io': []
        }
        
        self.patch_metrics = defaultdict(list)
        self.method_performance = defaultdict(lambda: defaultdict(list))
        
        # Setup plot style
        plt.style.use('seaborn-v0_8-darkgrid')
        sns.set_palette("husl")
        
    def collect_system_metrics(self):
        """Collect current system performance metrics"""
        try:
            # CPU usage
            cpu_cmd = "top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1"
            cpu = float(subprocess.check_output(cpu_cmd, shell=True).decode().strip())
            
            # Memory usage
            mem_cmd = "free | grep Mem | awk '{print ($3/$2) * 100.0}'"
            memory = float(subprocess.check_output(mem_cmd, shell=True).decode().strip())
            
            # Disk I/O (simplified - requires iostat)
            try:
                disk_cmd = "iostat -x 1 2 | tail -n 2 | awk '{print $14}'"
                disk_io = float(subprocess.check_output(disk_cmd, shell=True).decode().strip())
            except:
                disk_io = 0.0
            
            # Network I/O (simplified)
            try:
                net_cmd = "cat /proc/net/dev | grep -E 'eth|wlan' | awk '{sum += $2 + $10} END {print sum}'"
                network_io = float(subprocess.check_output(net_cmd, shell=True).decode().strip())
            except:
                network_io = 0.0
            
            return {
                'timestamp': datetime.now(),
                'cpu_usage': cpu,
                'memory_usage': memory,
                'disk_io': disk_io,
                'network_io': network_io
            }
        except Exception as e:
            print(f"Error collecting metrics: {e}")
            return None
    
    def parse_timing_logs(self):
        """Parse timing logs from patch application methods"""
        timing_files = {
            'quilt': f"{self.results_dir}/patch_timing_quilt.log",
            'git': f"{self.results_dir}/patch_timing_git.log",
            'script': f"{self.results_dir}/patch_timing_script.log"
        }
        
        timing_data = {}
        for method, filepath in timing_files.items():
            if os.path.exists(filepath):
                try:
                    with open(filepath, 'r') as f:
                        times = [float(line.strip()) for line in f if line.strip()]
                        timing_data[method] = times
                except Exception as e:
                    print(f"Error reading {filepath}: {e}")
        
        return timing_data
    
    def load_benchmark_data(self):
        """Load benchmark summary data"""
        csv_path = f"{self.results_dir}/benchmark_summary.csv"
        if os.path.exists(csv_path):
            try:
                return pd.read_csv(csv_path)
            except Exception as e:
                print(f"Error loading benchmark data: {e}")
        return None
    
    def monitor_thread(self):
        """Background thread for continuous monitoring"""
        while self.monitoring:
            metrics = self.collect_system_metrics()
            if metrics:
                self.data_queue.put(('system', metrics))
            
            # Check for new patch timing data
            timing_data = self.parse_timing_logs()
            if timing_data:
                self.data_queue.put(('timing', timing_data))
            
            time.sleep(5)  # Collect every 5 seconds
    
    def create_dashboard(self):
        """Create the monitoring dashboard"""
        # Create figure with subplots
        self.fig = plt.figure(figsize=(20, 12))
        self.fig.suptitle('prplOS Patch Management Monitoring Dashboard', fontsize=16)
        
        # Define grid layout
        gs = self.fig.add_gridspec(3, 3, hspace=0.3, wspace=0.3)
        
        # System metrics plots
        self.ax_cpu = self.fig.add_subplot(gs[0, 0])
        self.ax_memory = self.fig.add_subplot(gs[0, 1])
        self.ax_io = self.fig.add_subplot(gs[0, 2])
        
        # Patch performance plots
        self.ax_timing = self.fig.add_subplot(gs[1, :2])
        self.ax_comparison = self.fig.add_subplot(gs[1, 2])
        
        # Summary and statistics
        self.ax_summary = self.fig.add_subplot(gs[2, :])
        
        # Initialize plots
        self.init_plots()
        
        # Start monitoring thread
        self.monitor_thread_obj = threading.Thread(target=self.monitor_thread)
        self.monitor_thread_obj.daemon = True
        self.monitor_thread_obj.start()
        
        # Setup animation
        self.ani = FuncAnimation(self.fig, self.update_plots, 
                               interval=self.update_interval, blit=False)
        
        plt.show()
    
    def init_plots(self):
        """Initialize all plots"""
        # CPU usage plot
        self.ax_cpu.set_title('CPU Usage (%)')
        self.ax_cpu.set_ylim(0, 100)
        self.cpu_line, = self.ax_cpu.plot([], [], 'b-', linewidth=2)
        
        # Memory usage plot
        self.ax_memory.set_title('Memory Usage (%)')
        self.ax_memory.set_ylim(0, 100)
        self.memory_line, = self.ax_memory.plot([], [], 'r-', linewidth=2)
        
        # I/O plot
        self.ax_io.set_title('I/O Activity')
        self.ax_io.set_ylabel('Rate')
        self.disk_line, = self.ax_io.plot([], [], 'g-', label='Disk', linewidth=2)
        self.net_line, = self.ax_io.plot([], [], 'm-', label='Network', linewidth=2)
        self.ax_io.legend()
        
        # Timing comparison
        self.ax_timing.set_title('Patch Application Times by Method')
        self.ax_timing.set_xlabel('Method')
        self.ax_timing.set_ylabel('Time (seconds)')
        
        # Method comparison
        self.ax_comparison.set_title('Performance Comparison')
        
        # Summary text
        self.ax_summary.axis('off')
        self.summary_text = self.ax_summary.text(0.02, 0.95, '', 
                                                transform=self.ax_summary.transAxes,
                                                verticalalignment='top',
                                                fontfamily='monospace',
                                                fontsize=10)
    
    def update_plots(self, frame):
        """Update all plots with latest data"""
        # Process queued data
        while not self.data_queue.empty():
            data_type, data = self.data_queue.get()
            
            if data_type == 'system':
                for key, value in data.items():
                    if key != 'timestamp':
                        self.system_metrics[key].append(value)
                    else:
                        self.system_metrics['timestamp'].append(value)
                
                # Keep only last 100 points
                for key in self.system_metrics:
                    if len(self.system_metrics[key]) > 100:
                        self.system_metrics[key] = self.system_metrics[key][-100:]
            
            elif data_type == 'timing':
                for method, times in data.items():
                    self.patch_metrics[method] = times
        
        # Update system metrics plots
        if self.system_metrics['timestamp']:
            timestamps = self.system_metrics['timestamp']
            
            # CPU
            self.cpu_line.set_data(range(len(timestamps)), 
                                 self.system_metrics['cpu_usage'])
            self.ax_cpu.set_xlim(0, max(100, len(timestamps)))
            
            # Memory
            self.memory_line.set_data(range(len(timestamps)), 
                                    self.system_metrics['memory_usage'])
            self.ax_memory.set_xlim(0, max(100, len(timestamps)))
            
            # I/O
            self.disk_line.set_data(range(len(timestamps)), 
                                  self.system_metrics['disk_io'])
            self.net_line.set_data(range(len(timestamps)), 
                                 self.system_metrics['network_io'])
            self.ax_io.set_xlim(0, max(100, len(timestamps)))
            self.ax_io.relim()
            self.ax_io.autoscale_view()
        
        # Update patch timing plots
        if self.patch_metrics:
            self.ax_timing.clear()
            self.ax_timing.set_title('Patch Application Times by Method')
            self.ax_timing.set_xlabel('Method')
            self.ax_timing.set_ylabel('Time (seconds)')
            
            # Box plot of timing data
            methods = list(self.patch_metrics.keys())
            data = [self.patch_metrics[m] for m in methods]
            
            bp = self.ax_timing.boxplot(data, labels=methods, patch_artist=True)
            for patch, color in zip(bp['boxes'], sns.color_palette()):
                patch.set_facecolor(color)
        
        # Update comparison plot
        benchmark_df = self.load_benchmark_data()
        if benchmark_df is not None:
            self.ax_comparison.clear()
            self.ax_comparison.set_title('Performance Comparison')
            
            # Create pivot table for heatmap
            pivot = benchmark_df.pivot_table(
                values='elapsed_time', 
                index='package', 
                columns='method',
                aggfunc=lambda x: float(x.iloc[0].split(':')[1]) if ':' in x.iloc[0] else float(x.iloc[0])
            )
            
            if not pivot.empty:
                sns.heatmap(pivot, annot=True, fmt='.2f', 
                          cmap='YlOrRd', ax=self.ax_comparison)
        
        # Update summary
        self.update_summary()
        
        return [self.cpu_line, self.memory_line, self.disk_line, 
                self.net_line, self.summary_text]
    
    def update_summary(self):
        """Update summary statistics"""
        summary_lines = [
            "=== prplOS Patch Management Summary ===\n",
            f"Dashboard Update: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"
        ]
        
        # System metrics summary
        if self.system_metrics['cpu_usage']:
            summary_lines.extend([
                "\nSystem Metrics (last 100 samples):",
                f"  CPU Usage:    Avg: {np.mean(self.system_metrics['cpu_usage']):.1f}% "
                f"Max: {np.max(self.system_metrics['cpu_usage']):.1f}%",
                f"  Memory Usage: Avg: {np.mean(self.system_metrics['memory_usage']):.1f}% "
                f"Max: {np.max(self.system_metrics['memory_usage']):.1f}%"
            ])
        
        # Patch timing summary
        if self.patch_metrics:
            summary_lines.append("\nPatch Application Performance:")
            for method, times in self.patch_metrics.items():
                if times:
                    summary_lines.append(
                        f"  {method:8s}: Avg: {np.mean(times):.2f}s "
                        f"Min: {np.min(times):.2f}s "
                        f"Max: {np.max(times):.2f}s "
                        f"(n={len(times)})"
                    )
            
            # Best method
            avg_times = {m: np.mean(t) for m, t in self.patch_metrics.items() if t}
            if avg_times:
                best_method = min(avg_times, key=avg_times.get)
                summary_lines.append(f"\nBest performing method: {best_method}")
        
        # Benchmark results
        benchmark_df = self.load_benchmark_data()
        if benchmark_df is not None:
            summary_lines.extend([
                "\nBenchmark Results:",
                f"  Total tests run: {len(benchmark_df)}",
                f"  Methods tested: {', '.join(benchmark_df['method'].unique())}",
                f"  Packages tested: {', '.join(benchmark_df['package'].unique())}"
            ])
        
        self.summary_text.set_text('\n'.join(summary_lines))
    
    def export_report(self, filename=None):
        """Export comprehensive analysis report"""
        if filename is None:
            filename = f"{self.results_dir}/analysis_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        
        report = {
            'timestamp': datetime.now().isoformat(),
            'system_metrics_summary': {},
            'patch_performance': {},
            'recommendations': []
        }
        
        # System metrics
        if self.system_metrics['cpu_usage']:
            report['system_metrics_summary'] = {
                'cpu': {
                    'average': float(np.mean(self.system_metrics['cpu_usage'])),
                    'max': float(np.max(self.system_metrics['cpu_usage'])),
                    'min': float(np.min(self.system_metrics['cpu_usage']))
                },
                'memory': {
                    'average': float(np.mean(self.system_metrics['memory_usage'])),
                    'max': float(np.max(self.system_metrics['memory_usage'])),
                    'min': float(np.min(self.system_metrics['memory_usage']))
                }
            }
        
        # Patch performance
        for method, times in self.patch_metrics.items():
            if times:
                report['patch_performance'][method] = {
                    'average': float(np.mean(times)),
                    'min': float(np.min(times)),
                    'max': float(np.max(times)),
                    'std_dev': float(np.std(times)),
                    'samples': len(times)
                }
        
        # Generate recommendations
        if report['patch_performance']:
            best_method = min(report['patch_performance'].items(), 
                            key=lambda x: x[1]['average'])[0]
            report['recommendations'].append(
                f"Use {best_method} method for optimal performance "
                f"(avg: {report['patch_performance'][best_method]['average']:.2f}s)"
            )
        
        # Save report
        with open(filename, 'w') as f:
            json.dump(report, f, indent=2)
        
        print(f"Report exported to: {filename}")
        return report
    
    def stop(self):
        """Stop monitoring and export final report"""
        self.monitoring = False
        if hasattr(self, 'monitor_thread_obj'):
            self.monitor_thread_obj.join()
        
        # Export final report
        report = self.export_report()
        
        # Save final plot
        if hasattr(self, 'fig'):
            self.fig.savefig(f"{self.results_dir}/final_dashboard.png", 
                           dpi=150, bbox_inches='tight')
        
        return report


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description='prplOS Patch Management Monitoring Dashboard'
    )
    parser.add_argument('--results-dir', default='/tmp/patch_results',
                      help='Directory containing patch results')
    parser.add_argument('--update-interval', type=int, default=1000,
                      help='Dashboard update interval in milliseconds')
    parser.add_argument('--export-only', action='store_true',
                      help='Export report without showing dashboard')
    
    args = parser.parse_args()
    
    # Create dashboard
    dashboard = PatchMonitorDashboard(
        results_dir=args.results_dir,
        update_interval=args.update_interval
    )
    
    if args.export_only:
        # Just export report
        report = dashboard.export_report()
        print(json.dumps(report, indent=2))
    else:
        # Show interactive dashboard
        try:
            dashboard.create_dashboard()
        except KeyboardInterrupt:
            print("\nShutting down dashboard...")
            report = dashboard.stop()
            print("\nFinal report:")
            print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()